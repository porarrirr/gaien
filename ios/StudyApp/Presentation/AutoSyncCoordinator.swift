import Foundation

@MainActor
final class AutoSyncCoordinator {
    private let syncRepository: any SyncRepository
    private let logger: AppLogger
    private let currentDataVersion: @MainActor () -> Int
    private let onSyncStatusChanged: @MainActor () -> Void

    private var delayTask: Task<Void, Never>?
    private var lastSyncedDataVersion: Int?
    private let blockedKey = "studyapp.sync.autoSyncBlockedUntilLocalChange"
    private let lastLifecycleSyncKey = "studyapp.sync.lastLifecycleAutoSyncAt"
    private let lifecycleSyncMinimumInterval: TimeInterval = 5 * 60
    private let syncBusyRetryDelayNanoseconds: UInt64 = 500_000_000
    private var pendingRequest: (reason: String, dataVersion: Int)?
    private var isRunning = false

    init(
        syncRepository: any SyncRepository,
        logger: AppLogger,
        currentDataVersion: @escaping @MainActor () -> Int,
        onSyncStatusChanged: @escaping @MainActor () -> Void
    ) {
        self.syncRepository = syncRepository
        self.logger = logger
        self.currentDataVersion = currentDataVersion
        self.onSyncStatusChanged = onSyncStatusChanged
    }

    func schedule(reason: String) {
        guard syncRepository.status.isAuthenticated else { return }

        if isBlockedUntilLocalChange {
            if reason.hasPrefix("data-version-") {
                isBlockedUntilLocalChange = false
            } else {
                logger.log(category: .sync, message: "Auto sync skipped", details: "reason=\(reason) blocked=true")
                return
            }
        }

        let dataVersion = currentDataVersion()
        if isLifecycleSyncReason(reason), shouldThrottleLifecycleSync(now: Date()) {
            logger.log(category: .sync, message: "Auto sync skipped", details: "reason=\(reason) recentlySynced=true")
            return
        }

        if lastSyncedDataVersion == dataVersion, !isLifecycleSyncReason(reason) {
            return
        }

        pendingRequest = (reason, dataVersion)
        delayTask?.cancel()
        delayTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self.runQueuedSync()
        }
    }

    func recordManualSyncApplied() {
        lastSyncedDataVersion = currentDataVersion()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastLifecycleSyncKey)
        isBlockedUntilLocalChange = false
    }

    func blockUntilLocalChange() {
        delayTask?.cancel()
        delayTask = nil
        pendingRequest = nil
        isBlockedUntilLocalChange = true
    }

    private func runQueuedSync() async {
        guard !isRunning else { return }

        while let request = pendingRequest {
            guard syncRepository.status.isAuthenticated else {
                pendingRequest = nil
                return
            }
            guard !syncRepository.status.isSyncing else {
                logger.log(category: .sync, message: "Auto sync delayed", details: "reason=\(request.reason) remoteSyncing=true")
                scheduleRetryForPendingSync()
                return
            }

            pendingRequest = nil
            isRunning = true
            do {
                logger.log(
                    category: .sync,
                    message: "Auto sync started",
                    details: "reason=\(request.reason) dataVersion=\(request.dataVersion)"
                )
                try await syncRepository.syncNow()
                onSyncStatusChanged()
                lastSyncedDataVersion = request.dataVersion
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastLifecycleSyncKey)
                logger.log(
                    category: .sync,
                    message: "Auto sync completed",
                    details: "reason=\(request.reason) dataVersion=\(request.dataVersion)"
                )
            } catch {
                logger.log(
                    category: .sync,
                    level: .warning,
                    message: "Auto sync failed",
                    details: "reason=\(request.reason)",
                    error: error
                )
            }
            isRunning = false
        }
    }

    private func scheduleRetryForPendingSync() {
        delayTask?.cancel()
        delayTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.syncBusyRetryDelayNanoseconds)
            await self.runQueuedSync()
        }
    }

    private var isBlockedUntilLocalChange: Bool {
        get { UserDefaults.standard.bool(forKey: blockedKey) }
        set { UserDefaults.standard.set(newValue, forKey: blockedKey) }
    }

    private func isLifecycleSyncReason(_ reason: String) -> Bool {
        reason == "scene-active" || reason == "app-load"
    }

    private func shouldThrottleLifecycleSync(now: Date) -> Bool {
        guard let lastSyncAt = syncRepository.status.lastSyncAt else { return false }
        let lastSyncDate = Date(timeIntervalSince1970: TimeInterval(lastSyncAt) / 1000)
        guard now.timeIntervalSince(lastSyncDate) < lifecycleSyncMinimumInterval else { return false }

        let lastLifecycleSyncAt = UserDefaults.standard.double(forKey: lastLifecycleSyncKey)
        guard lastLifecycleSyncAt > 0 else { return false }
        return now.timeIntervalSince1970 - lastLifecycleSyncAt < lifecycleSyncMinimumInterval
    }
}
