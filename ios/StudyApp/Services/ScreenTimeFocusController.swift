import FamilyControls
import Foundation

@MainActor
final class ScreenTimeFocusController: ObservableObject {
    @Published private(set) var settings: ScreenTimeFocusSettings
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var accessSnapshot: ScreenTimeAccessSnapshot?

    private let accessEngine: ScreenTimeAccessEngine

    init(accessEngine: ScreenTimeAccessEngine = ScreenTimeAccessEngine()) {
        self.accessEngine = accessEngine
        self.settings = ScreenTimeFocusShared.loadSettings()
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        self.accessSnapshot = try? accessEngine.snapshot()
    }

    var isAvailable: Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return false
    }

    var authorizationStatusText: String {
        if #available(iOS 26.4, *), authorizationStatus == .approvedWithDataAccess {
            return "許可済み"
        }
        switch authorizationStatus {
        case .notDetermined:
            return "未許可"
        case .denied:
            return "拒否"
        case .approved:
            return "許可済み"
        case .approvedWithDataAccess:
            return "許可済み"
        @unknown default:
            return "不明"
        }
    }

    var isAuthorized: Bool {
        if authorizationStatus == .approved {
            return true
        }
        if #available(iOS 26.4, *), authorizationStatus == .approvedWithDataAccess {
            return true
        }
        return false
    }

    var allowedApplicationCount: Int {
        settings.allowedApplicationTokens.count
    }

    var allowedWebDomainCount: Int {
        settings.allowedWebDomainTokens.count
    }

    var isSettingsLocked: Bool {
        settings.isSettingsLocked
    }

    var settingsLockExpiryDate: Date? {
        settings.settingsLockExpiryDate
    }

    var ticketLedger: ScreenTimeTicketLedger? {
        accessSnapshot?.ledger
    }

    var policyDecision: ScreenTimePolicyDecision? {
        accessSnapshot?.decision
    }

    func refresh(referenceDate: Date = Date()) {
        settings = ScreenTimeFocusShared.loadSettings()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        accessSnapshot = try? accessEngine.snapshot(referenceDate: referenceDate)
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw ScreenTimeFocusError.unavailable }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refresh()
    }

    func updateSettings(_ update: (inout ScreenTimeFocusSettings) -> Void) throws {
        if settings.isSettingsLocked, let expiryDate = settings.settingsLockExpiryDate {
            throw ScreenTimeFocusError.settingsLocked(until: expiryDate)
        }

        let previous = settings
        var next = settings
        update(&next)
        next.normalizeActivitySelection()
        try next.validateMonitoringConfiguration()
        try save(next)

        do {
            try synchronize(settings: next)
        } catch {
            _ = ScreenTimeFocusShared.saveSettings(previous)
            settings = previous
            try? synchronize(settings: previous)
            throw error
        }
    }

    func activateSettingsLock(months: Int, days: Int, referenceDate: Date = Date()) throws {
        if settings.isSettingsLocked, let expiryDate = settings.settingsLockExpiryDate {
            throw ScreenTimeFocusError.settingsAlreadyLocked(until: expiryDate)
        }
        guard let expiryDate = ScreenTimeFocusSettings.lockExpiryDate(
            from: referenceDate,
            months: months,
            days: days
        ) else {
            throw ScreenTimeFocusError.invalidLockDuration
        }
        try settings.validateMonitoringConfiguration()
        try synchronize(settings: settings)
        var next = settings
        next.settingsLockedUntilEpochMilliseconds = expiryDate.epochMilliseconds
        try save(next)
        refresh(referenceDate: referenceDate)
    }

    func addScheduleSlot() throws {
        try updateSettings { settings in
            let nextIndex = settings.scheduleSlots.count + 1
            settings.scheduleSlots.append(
                FocusScheduleSlot(title: "時間帯 \(nextIndex)")
            )
        }
    }

    func removeScheduleSlot(id: String) throws {
        try updateSettings { settings in
            settings.scheduleSlots.removeAll { $0.id == id }
        }
    }

    @discardableResult
    func startTicket(referenceDate: Date = Date()) throws -> ScreenTimeTicketLedger {
        guard isAuthorized else { throw ScreenTimeFocusError.authorizationRequired }
        let ledger = try accessEngine.startTicket(referenceDate: referenceDate)
        refresh(referenceDate: referenceDate)
        return ledger
    }

    func applyTimerRestrictionIfNeeded(isRunning: Bool, referenceDate: Date = Date()) throws {
        let runtime = ScreenTimeRuntimeState(
            timerIsRunning: isRunning,
            updatedAt: referenceDate.epochMilliseconds
        )
        _ = ScreenTimeFocusShared.saveRuntimeState(runtime)
        if settings.isEnabled, isRunning || settings.ticketRestrictionEnabled || settings.scheduledRestrictionEnabled {
            guard isAuthorized else { throw ScreenTimeFocusError.authorizationRequired }
        }
        _ = try accessEngine.applyCurrentPolicy(referenceDate: referenceDate)
        refresh(referenceDate: referenceDate)
    }

    func clearTimerRestriction() {
        let runtime = ScreenTimeRuntimeState(timerIsRunning: false)
        _ = ScreenTimeFocusShared.saveRuntimeState(runtime)
        _ = try? accessEngine.applyCurrentPolicy()
        refresh()
    }

    func restoreTimerRestriction(activeTimerIsRunning: Bool) {
        try? applyTimerRestrictionIfNeeded(isRunning: activeTimerIsRunning)
    }

    func syncScheduleMonitoringIfNeeded(referenceDate: Date = Date()) throws {
        guard !settings.isEnabled || isAuthorized else {
            throw ScreenTimeFocusError.authorizationRequired
        }
        try accessEngine.syncMonitoring(settings: settings, referenceDate: referenceDate)
        _ = try accessEngine.applyCurrentPolicy(referenceDate: referenceDate)
        refresh(referenceDate: referenceDate)
    }

    func applyScheduleRestrictionIfNeeded(referenceDate: Date = Date()) throws {
        guard !settings.isEnabled || isAuthorized else {
            throw ScreenTimeFocusError.authorizationRequired
        }
        _ = try accessEngine.applyCurrentPolicy(referenceDate: referenceDate)
        refresh(referenceDate: referenceDate)
    }

    func clearAllRestrictionsAndMonitoring() {
        accessEngine.stopAllMonitoringAndClearRestrictions()
        refresh()
    }

    private func synchronize(settings: ScreenTimeFocusSettings) throws {
        if settings.isEnabled {
            guard isAuthorized else { throw ScreenTimeFocusError.authorizationRequired }
        }
        try accessEngine.syncMonitoring(settings: settings)
        _ = try accessEngine.applyCurrentPolicy()
        refresh()
    }

    private func save(_ next: ScreenTimeFocusSettings) throws {
        guard ScreenTimeFocusShared.saveSettings(next) else {
            throw ScreenTimeFocusError.settingsSaveFailed
        }
        settings = next
    }
}
