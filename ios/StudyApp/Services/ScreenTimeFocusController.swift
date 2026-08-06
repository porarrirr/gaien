import FamilyControls
import Foundation

@MainActor
final class ScreenTimeFocusController: ObservableObject {
    @Published private(set) var settings: ScreenTimeFocusSettings
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var accessSnapshot: ScreenTimeAccessSnapshot?
    @Published private(set) var requiresRestoredActivitySelection: Bool
    @Published private(set) var usageSummary: ScreenTimeUsageSummary
    /// 制限をオンにしたまま Screen Time の許可が外れている状態。
    /// この間 OS 側のシールドは消えるため、隠さずに知らせる。
    @Published private(set) var isProtectionInterrupted: Bool

    private let accessEngine: ScreenTimeAccessEngine
    var settingsDidChange: (() -> Void)?

    init(accessEngine: ScreenTimeAccessEngine = ScreenTimeAccessEngine()) {
        self.accessEngine = accessEngine
        self.settings = ScreenTimeFocusShared.loadSettings()
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        self.accessSnapshot = try? accessEngine.snapshot()
        self.requiresRestoredActivitySelection = ScreenTimeFocusShared.isRestoredSelectionRequired
        self.usageSummary = (try? accessEngine.usageSummary()) ?? .empty
        self.isProtectionInterrupted = false
        detectProtectionInterruption()
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

    var budgetApplicationCount: Int {
        settings.budgetApplicationTokens.count
    }

    var budgetCategoryCount: Int {
        settings.budgetCategoryTokens.count
    }

    var budgetWebDomainCount: Int {
        settings.budgetWebDomainTokens.count
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

    /// 使用量マイルストーンの段間隔（分）。表示を「目安」と伝えるために使う。
    var usageResolutionMinutes: Int {
        accessSnapshot?.usageResolutionMinutes ?? 0
    }

    func refresh(referenceDate: Date = Date()) {
        settings = ScreenTimeFocusShared.loadSettings()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        accessSnapshot = try? accessEngine.snapshot(referenceDate: referenceDate)
        requiresRestoredActivitySelection = ScreenTimeFocusShared.isRestoredSelectionRequired
        usageSummary = (try? accessEngine.usageSummary(referenceDate: referenceDate)) ?? .empty
        detectProtectionInterruption(referenceDate: referenceDate)
    }

    /// 制限がオンのまま許可が外れていたら、その日の記録に残してから状態を反映する。
    ///
    /// iOS の設定から Screen Time の許可を取り消すとシールドは即座に消える。
    /// アプリ側で止められはしないが、黙って無効化されるのは防ぐ。
    private func detectProtectionInterruption(referenceDate: Date = Date()) {
        let interrupted = settings.isEnabled && !isAuthorized
        if interrupted, !isProtectionInterrupted {
            accessEngine.recordProtectionInterruption(referenceDate: referenceDate)
            usageSummary = (try? accessEngine.usageSummary(referenceDate: referenceDate)) ?? usageSummary
        }
        isProtectionInterrupted = interrupted
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw ScreenTimeFocusError.unavailable }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        if !isAuthorized {
            var resetSettings = ScreenTimeFocusShared.loadSettings()
            resetSettings.activitySelection = FamilyActivitySelection(includeEntireCategory: true)
            resetSettings.budgetSelection = FamilyActivitySelection(includeEntireCategory: true)
            if resetSettings.selectionWasConfigured
                || resetSettings.budgetSelectionWasConfigured
                || resetSettings.requiresAllowedSelection
                || resetSettings.requiresBudgetSelection {
                ScreenTimeFocusShared.setRestoredSelectionRequired(true)
            }
            try save(resetSettings)
        }
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
        if next.activitySelection != previous.activitySelection {
            next.selectionWasConfigured = !next.allowedApplicationTokens.isEmpty
                || !next.allowedWebDomainTokens.isEmpty
        }
        if next.budgetSelection != previous.budgetSelection {
            next.budgetSelectionWasConfigured = next.hasBudgetSelection
        }
        next.updatedAt = nextSettingsTimestamp(after: previous.updatedAt)
        next.normalizeActivitySelection()
        try next.validateMonitoringConfiguration()
        try save(next)

        do {
            try synchronize(settings: next)
        } catch {
            try rollbackSettings(to: previous, after: error)
        }
        clearRestoredSelectionRequirementIfResolved(using: next)
        settingsDidChange?()
    }

    /// 同期復元や Screen Time の再許可で端末固有トークンが消えた場合、
    /// 必要な選択がすべてそろった時点でだけ復元警告を解除する。
    private func clearRestoredSelectionRequirementIfResolved(using settings: ScreenTimeFocusSettings) {
        guard requiresRestoredActivitySelection else { return }
        let hasAllowedSelection = !settings.requiresAllowedSelection
            || !settings.allowedApplicationTokens.isEmpty
            || !settings.allowedWebDomainTokens.isEmpty
        let hasBudgetSelection = !settings.requiresBudgetSelection || settings.hasBudgetSelection
        guard hasAllowedSelection, hasBudgetSelection else { return }
        ScreenTimeFocusShared.setRestoredSelectionRequired(false)
        requiresRestoredActivitySelection = false
    }

    /// おすすめ設定を丸ごと当てる。対象アプリの選択は端末固有なのでそのまま残す。
    func applyPreset(_ preset: ScreenTimeFocusPreset) throws {
        try updateSettings { settings in
            preset.apply(&settings)
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
        next.updatedAt = nextSettingsTimestamp(after: settings.updatedAt)
        try save(next)
        refresh(referenceDate: referenceDate)
        settingsDidChange?()
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

    /// 学習実績を持ち時間へ反映する。ホストアプリだけが呼ぶ。
    func applyStudyProgress(
        progress: ScreenTimeDailyGoalProgress,
        goalReached: Bool,
        referenceDate: Date = Date()
    ) throws {
        guard settings.isEnabled,
              settings.budgetRestrictionEnabled || settings.goalRestrictionEnabled else {
            return
        }
        _ = try accessEngine.applyStudyProgress(
            progress: progress,
            goalReached: goalReached,
            referenceDate: referenceDate
        )
    }

    func applyTimerRestrictionIfNeeded(
        isRunning: Bool,
        restrictionEndDate: Date? = nil,
        referenceDate: Date = Date()
    ) throws {
        let runtime = ScreenTimeRuntimeState(
            timerIsRunning: isRunning,
            timerRestrictionEndsAt: isRunning ? restrictionEndDate?.epochMilliseconds : nil,
            updatedAt: referenceDate.epochMilliseconds
        )
        guard ScreenTimeFocusShared.saveRuntimeState(runtime) else {
            throw ScreenTimeFocusError.settingsSaveFailed
        }
        if settings.isEnabled, isRunning || settings.activeRuleCount > 0 {
            guard isAuthorized else { throw ScreenTimeFocusError.authorizationRequired }
        }
        try accessEngine.syncTimerExpiryMonitoring(
            settings: settings,
            runtimeState: runtime,
            referenceDate: referenceDate
        )
        _ = try accessEngine.applyCurrentPolicy(referenceDate: referenceDate)
        refresh(referenceDate: referenceDate)
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

    func resolveRestoredActivitySelections(
        allowedSelection: FamilyActivitySelection,
        budgetSelection: FamilyActivitySelection
    ) throws {
        let previous = settings
        var next = settings
        next.activitySelection = allowedSelection
        next.budgetSelection = budgetSelection
        next.normalizeActivitySelection()
        let hasAllowedSelection = !next.allowedApplicationTokens.isEmpty
            || !next.allowedWebDomainTokens.isEmpty
        guard !next.requiresAllowedSelection || hasAllowedSelection else {
            throw ScreenTimeFocusError.missingAllowedApplications
        }
        guard !next.requiresBudgetSelection || next.hasBudgetSelection else {
            throw ScreenTimeFocusError.missingBudgetTargets
        }
        next.selectionWasConfigured = hasAllowedSelection
        next.budgetSelectionWasConfigured = next.hasBudgetSelection
        try next.validateMonitoringConfiguration()
        try save(next)
        ScreenTimeFocusShared.setRestoredSelectionRequired(false)

        do {
            try synchronize(settings: next)
        } catch {
            ScreenTimeFocusShared.setRestoredSelectionRequired(true)
            try rollbackSettings(to: previous, after: error)
        }
        refresh()
    }

    /// 設定保存後のOS監視同期に失敗した場合、永続値と監視を両方とも以前の状態へ戻す。
    /// どちらかの復元に失敗したときは、元のエラーで隠さず不整合を利用者へ伝える。
    private func rollbackSettings(
        to previous: ScreenTimeFocusSettings,
        after originalError: Error
    ) throws -> Never {
        guard ScreenTimeFocusShared.saveSettings(previous) else {
            throw ScreenTimeFocusError.settingsRollbackFailed(
                original: originalError.localizedDescription,
                rollback: ScreenTimeFocusError.settingsSaveFailed.localizedDescription
            )
        }
        settings = previous
        do {
            try synchronize(settings: previous)
        } catch {
            throw ScreenTimeFocusError.settingsRollbackFailed(
                original: originalError.localizedDescription,
                rollback: error.localizedDescription
            )
        }
        throw originalError
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

    private func nextSettingsTimestamp(after previous: Int64) -> Int64 {
        max(Date().epochMilliseconds, previous + 1)
    }
}
