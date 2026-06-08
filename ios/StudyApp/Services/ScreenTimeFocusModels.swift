import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

struct FocusScheduleSlot: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var isEnabled: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    init(
        id: String = UUID().uuidString,
        title: String = "集中時間",
        isEnabled: Bool = true,
        startHour: Int = 19,
        startMinute: Int = 0,
        endHour: Int = 21,
        endMinute: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    var activityName: DeviceActivityName {
        DeviceActivityName("studyapp.focus.schedule.\(id)")
    }

    var startDateComponents: DateComponents {
        DateComponents(hour: startHour, minute: startMinute)
    }

    var endDateComponents: DateComponents {
        DateComponents(hour: endHour, minute: endMinute)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let currentMinute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinuteOfDay = startHour * 60 + startMinute
        let endMinuteOfDay = endHour * 60 + endMinute

        guard startMinuteOfDay != endMinuteOfDay else { return false }
        if startMinuteOfDay < endMinuteOfDay {
            return currentMinute >= startMinuteOfDay && currentMinute < endMinuteOfDay
        }
        return currentMinute >= startMinuteOfDay || currentMinute < endMinuteOfDay
    }
}

struct ScreenTimeDailyGoalProgress: Codable, Equatable {
    var dayStart: Int64
    var studyMinutes: Int
    var targetMinutes: Int
    var updatedAt: Int64

    var hasTarget: Bool {
        targetMinutes > 0
    }

    var hasReachedTarget: Bool {
        hasTarget && studyMinutes >= targetMinutes
    }

    func isForDay(containing date: Date, calendar: Calendar = .current) -> Bool {
        dayStart == Self.epochMilliseconds(for: calendar.startOfDay(for: date))
    }

    func unlocksRestrictions(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        isForDay(containing: date, calendar: calendar) && hasReachedTarget
    }

    private static func epochMilliseconds(for date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1_000)
    }
}

enum ScreenTimeRestrictionApplyResult: Equatable {
    case inactive
    case missingAllowedSelection
    case skippedDailyGoalReached
    case applied
}

struct ScreenTimeFocusSettings: Codable, Equatable {
    var isEnabled: Bool
    var timerRestrictionEnabled: Bool
    var scheduledRestrictionEnabled: Bool
    var unlockRestrictionsWhenDailyGoalReached: Bool
    var scheduleSlots: [FocusScheduleSlot]
    var activitySelection: FamilyActivitySelection
    /// Epoch milliseconds. While `Date() < expiry`, all Screen Time settings are read-only in-app.
    var settingsLockedUntilEpochMilliseconds: Int64?

    init(
        isEnabled: Bool = false,
        timerRestrictionEnabled: Bool = false,
        scheduledRestrictionEnabled: Bool = false,
        unlockRestrictionsWhenDailyGoalReached: Bool = false,
        scheduleSlots: [FocusScheduleSlot] = [],
        activitySelection: FamilyActivitySelection = FamilyActivitySelection(),
        settingsLockedUntilEpochMilliseconds: Int64? = nil
    ) {
        self.isEnabled = isEnabled
        self.timerRestrictionEnabled = timerRestrictionEnabled
        self.scheduledRestrictionEnabled = scheduledRestrictionEnabled
        self.unlockRestrictionsWhenDailyGoalReached = unlockRestrictionsWhenDailyGoalReached
        self.scheduleSlots = scheduleSlots
        self.activitySelection = activitySelection
        self.settingsLockedUntilEpochMilliseconds = settingsLockedUntilEpochMilliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case timerRestrictionEnabled
        case scheduledRestrictionEnabled
        case unlockRestrictionsWhenDailyGoalReached
        case scheduleSlots
        case activitySelection
        case settingsLockedUntilEpochMilliseconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        timerRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .timerRestrictionEnabled) ?? false
        scheduledRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduledRestrictionEnabled) ?? false
        unlockRestrictionsWhenDailyGoalReached = try container.decodeIfPresent(Bool.self, forKey: .unlockRestrictionsWhenDailyGoalReached) ?? false
        scheduleSlots = try container.decodeIfPresent([FocusScheduleSlot].self, forKey: .scheduleSlots) ?? []
        activitySelection = try container.decodeIfPresent(FamilyActivitySelection.self, forKey: .activitySelection) ?? FamilyActivitySelection()
        settingsLockedUntilEpochMilliseconds = try container.decodeIfPresent(Int64.self, forKey: .settingsLockedUntilEpochMilliseconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(timerRestrictionEnabled, forKey: .timerRestrictionEnabled)
        try container.encode(scheduledRestrictionEnabled, forKey: .scheduledRestrictionEnabled)
        try container.encode(unlockRestrictionsWhenDailyGoalReached, forKey: .unlockRestrictionsWhenDailyGoalReached)
        try container.encode(scheduleSlots, forKey: .scheduleSlots)
        try container.encode(activitySelection, forKey: .activitySelection)
        try container.encodeIfPresent(settingsLockedUntilEpochMilliseconds, forKey: .settingsLockedUntilEpochMilliseconds)
    }

    var settingsLockExpiryDate: Date? {
        guard let settingsLockedUntilEpochMilliseconds else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(settingsLockedUntilEpochMilliseconds) / 1_000)
    }

    var isSettingsLocked: Bool {
        isSettingsLocked(at: Date())
    }

    func isSettingsLocked(at date: Date) -> Bool {
        guard let expiryDate = settingsLockExpiryDate else { return false }
        return date < expiryDate
    }

    static func lockExpiryDate(
        from startDate: Date,
        months: Int,
        days: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard months > 0 || days > 0 else { return nil }
        var components = DateComponents()
        components.month = months
        components.day = days
        return calendar.date(byAdding: components, to: startDate)
    }

    var allowedApplicationTokens: Set<ApplicationToken> {
        activitySelection.applicationTokens
    }

    var allowedWebDomainTokens: Set<WebDomainToken> {
        activitySelection.webDomainTokens
    }

    var enabledScheduleSlots: [FocusScheduleSlot] {
        guard isEnabled, scheduledRestrictionEnabled else { return [] }
        return scheduleSlots.filter(\.isEnabled)
    }

    var canApplyRestrictions: Bool {
        isEnabled && (!allowedApplicationTokens.isEmpty || !allowedWebDomainTokens.isEmpty)
    }

    func activeScheduleSlots(at date: Date = Date(), calendar: Calendar = .current) -> [FocusScheduleSlot] {
        enabledScheduleSlots.filter { $0.contains(date, calendar: calendar) }
    }

    func hasActiveScheduleSlot(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        !activeScheduleSlots(at: date, calendar: calendar).isEmpty
    }

    func shouldUnlockRestrictionsForDailyGoal(
        progress: ScreenTimeDailyGoalProgress?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard isEnabled, unlockRestrictionsWhenDailyGoalReached, let progress else { return false }
        return progress.unlocksRestrictions(on: referenceDate, calendar: calendar)
    }
}

enum ScreenTimeFocusShared {
    static let appGroupIdentifier = "group.com.studyapp.ios.shared"
    static let settingsKey = "screenTimeFocusSettings.v1"
    static let dailyGoalProgressKey = "screenTimeFocusDailyGoalProgress.v1"
    static let scheduleActivityNamePrefix = "studyapp.focus.schedule."
    static let timerStoreName = ManagedSettingsStore.Name("studyapp.focus.timer")
    static let scheduleStoreName = ManagedSettingsStore.Name("studyapp.focus.schedule")

    static var allScheduleActivityNames: [DeviceActivityName] {
        loadSettings().scheduleSlots.map(\.activityName)
    }

    static func loadSettings() -> ScreenTimeFocusSettings {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(ScreenTimeFocusSettings.self, from: data) else {
            return ScreenTimeFocusSettings()
        }
        return settings
    }

    @discardableResult
    static func saveSettings(_ settings: ScreenTimeFocusSettings) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(settings) else {
            return false
        }
        defaults.set(data, forKey: settingsKey)
        return true
    }

    static func loadDailyGoalProgress() -> ScreenTimeDailyGoalProgress? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: dailyGoalProgressKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ScreenTimeDailyGoalProgress.self, from: data)
    }

    @discardableResult
    static func saveDailyGoalProgress(_ progress: ScreenTimeDailyGoalProgress) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(progress) else {
            return false
        }
        defaults.set(data, forKey: dailyGoalProgressKey)
        return true
    }

    static func applyRestrictions(
        using store: ManagedSettingsStore,
        settings: ScreenTimeFocusSettings,
        referenceDate: Date = Date()
    ) -> ScreenTimeRestrictionApplyResult {
        guard settings.isEnabled else {
            clearRestrictions(using: store)
            return .inactive
        }

        guard settings.canApplyRestrictions else {
            clearRestrictions(using: store)
            return .missingAllowedSelection
        }

        if settings.shouldUnlockRestrictionsForDailyGoal(
            progress: loadDailyGoalProgress(),
            referenceDate: referenceDate
        ) {
            clearRestrictions(using: store)
            return .skippedDailyGoalReached
        }

        store.shield.applicationCategories = .all(except: settings.allowedApplicationTokens)
        store.shield.webDomainCategories = .all(except: settings.allowedWebDomainTokens)
        return .applied
    }

    static func clearRestrictions(using store: ManagedSettingsStore) {
        store.shield.applicationCategories = nil
        store.shield.applications = nil
        store.shield.webDomainCategories = nil
        store.shield.webDomains = nil
    }
}
