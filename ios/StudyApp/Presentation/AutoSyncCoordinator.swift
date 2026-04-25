import Foundation

@MainActor
final class AutoSyncCoordinator {
    private let syncRepository: FirebaseSyncRepository
    private let logger: AppLogger
    private let currentDataVersion: @MainActor () -> Int
    private let onSyncStatusChanged: @MainActor () -> Void

    private var delayTask: Task<Void, Never>?
    private var lastSyncedDataVersion: Int?
    private let blockedKey = "studyapp.sync.autoSyncBlockedUntilLocalChange"
    private var pendingRequest: (reason: String, dataVersion: Int)?
    private var isRunning = false

    init(
        syncRepository: FirebaseSyncRepository,
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
        if lastSyncedDataVersion == dataVersion, reason != "scene-active", reason != "app-load" {
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
            guard !syncRepository.status.isSyncing else { return }

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

    private var isBlockedUntilLocalChange: Bool {
        get { UserDefaults.standard.bool(forKey: blockedKey) }
        set { UserDefaults.standard.set(newValue, forKey: blockedKey) }
    }
}
