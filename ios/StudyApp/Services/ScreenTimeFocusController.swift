import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTimeFocusError: LocalizedError {
    case unavailable
    case authorizationRequired
    case missingAllowedApplications
    case settingsSaveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Screen Time APIはこの環境では利用できません"
        case .authorizationRequired:
            return "Screen Timeの許可が必要です"
        case .missingAllowedApplications:
            return "許可するアプリを選択してください"
        case .settingsSaveFailed:
            return "集中制限の設定を保存できませんでした"
        }
    }
}

@MainActor
final class ScreenTimeFocusController: ObservableObject {
    @Published private(set) var settings: ScreenTimeFocusSettings
    @Published private(set) var authorizationStatus: AuthorizationStatus

    private let timerStore = ManagedSettingsStore(named: ScreenTimeFocusShared.timerStoreName)
    private let scheduleStore = ManagedSettingsStore(named: ScreenTimeFocusShared.scheduleStoreName)
    private let deviceActivityCenter = DeviceActivityCenter()

    init() {
        self.settings = ScreenTimeFocusShared.loadSettings()
        self.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
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

    func refresh() {
        settings = ScreenTimeFocusShared.loadSettings()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw ScreenTimeFocusError.unavailable }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refresh()
    }

    func updateSettings(_ update: (inout ScreenTimeFocusSettings) -> Void) throws {
        var next = settings
        update(&next)
        try save(next)
        if next.isEnabled, next.scheduledRestrictionEnabled {
            stopStudyAppScheduleMonitoring()
            try syncScheduleMonitoring(settings: next)
        } else {
            stopStudyAppScheduleMonitoring()
            ScreenTimeFocusShared.clearRestrictions(using: scheduleStore)
        }
    }

    func addScheduleSlot() throws {
        try updateSettings { settings in
            let nextIndex = settings.scheduleSlots.count + 1
            settings.scheduleSlots.append(
                FocusScheduleSlot(title: "集中時間 \(nextIndex)")
            )
        }
    }

    func removeScheduleSlot(id: String) throws {
        try updateSettings { settings in
            settings.scheduleSlots.removeAll { $0.id == id }
        }
    }

    func applyTimerRestrictionIfNeeded(isRunning: Bool) throws {
        guard isRunning else {
            clearTimerRestriction()
            return
        }
        guard settings.isEnabled, settings.timerRestrictionEnabled else { return }
        guard isAuthorized else { throw ScreenTimeFocusError.authorizationRequired }
        guard ScreenTimeFocusShared.applyRestrictions(using: timerStore, settings: settings) else {
            throw ScreenTimeFocusError.missingAllowedApplications
        }
    }

    func clearTimerRestriction() {
        ScreenTimeFocusShared.clearRestrictions(using: timerStore)
    }

    func restoreTimerRestriction(activeTimerIsRunning: Bool) {
        do {
            try applyTimerRestrictionIfNeeded(isRunning: activeTimerIsRunning)
        } catch {
            clearTimerRestriction()
        }
    }

    func syncScheduleMonitoringIfNeeded() throws {
        guard settings.isEnabled, settings.scheduledRestrictionEnabled else {
            stopStudyAppScheduleMonitoring()
            ScreenTimeFocusShared.clearRestrictions(using: scheduleStore)
            return
        }
        stopStudyAppScheduleMonitoring()
        try syncScheduleMonitoring(settings: settings)
    }

    private func save(_ next: ScreenTimeFocusSettings) throws {
        guard ScreenTimeFocusShared.saveSettings(next) else {
            throw ScreenTimeFocusError.settingsSaveFailed
        }
        settings = next
    }

    private func syncScheduleMonitoring(settings: ScreenTimeFocusSettings) throws {
        guard isAuthorized else { throw ScreenTimeFocusError.authorizationRequired }
        guard settings.canApplyRestrictions else { throw ScreenTimeFocusError.missingAllowedApplications }

        for slot in settings.enabledScheduleSlots {
            let schedule = DeviceActivitySchedule(
                intervalStart: slot.startDateComponents,
                intervalEnd: slot.endDateComponents,
                repeats: true
            )
            try deviceActivityCenter.startMonitoring(slot.activityName, during: schedule)
        }
    }

    private func stopStudyAppScheduleMonitoring() {
        let names = deviceActivityCenter.activities.filter {
            $0.rawValue.hasPrefix(ScreenTimeFocusShared.scheduleActivityNamePrefix)
        }
        guard !names.isEmpty else { return }
        deviceActivityCenter.stopMonitoring(names)
    }
}
