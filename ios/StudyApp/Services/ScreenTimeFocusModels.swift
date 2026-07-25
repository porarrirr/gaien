import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTimeDateMath {
    static func epochMilliseconds(for date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1_000)
    }

    static func date(fromEpochMilliseconds value: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(value) / 1_000)
    }
}

enum FocusScheduleBehavior: String, Codable, CaseIterable, Hashable {
    case allow
    case block

    var title: String {
        switch self {
        case .allow:
            return "無料開放"
        case .block:
            return "使用禁止"
        }
    }
}

struct FocusScheduleSlot: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var isEnabled: Bool
    var behavior: FocusScheduleBehavior
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    /// Calendar weekday values (1 = Sunday … 7 = Saturday) the slot applies to.
    var weekdays: Set<Int>

    static let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    init(
        id: String = UUID().uuidString,
        title: String = "時間帯",
        isEnabled: Bool = true,
        behavior: FocusScheduleBehavior = .block,
        startHour: Int = 19,
        startMinute: Int = 0,
        endHour: Int = 21,
        endMinute: Int = 0,
        weekdays: Set<Int> = FocusScheduleSlot.allWeekdays
    ) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.behavior = behavior
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.weekdays = weekdays.intersection(FocusScheduleSlot.allWeekdays)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isEnabled
        case behavior
        case startHour
        case startMinute
        case endHour
        case endMinute
        case weekdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        behavior = try container.decodeIfPresent(FocusScheduleBehavior.self, forKey: .behavior) ?? .block
        startHour = try container.decode(Int.self, forKey: .startHour)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endHour = try container.decode(Int.self, forKey: .endHour)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        if let decodedWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) {
            weekdays = decodedWeekdays.intersection(FocusScheduleSlot.allWeekdays)
        } else {
            weekdays = FocusScheduleSlot.allWeekdays
        }
    }

    var activityName: DeviceActivityName {
        DeviceActivityName("\(ScreenTimeFocusShared.scheduleActivityNamePrefix)\(id)")
    }

    var startDateComponents: DateComponents {
        DateComponents(hour: startHour, minute: startMinute)
    }

    var endDateComponents: DateComponents {
        DateComponents(hour: endHour, minute: endMinute)
    }

    var durationMinutes: Int {
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        guard start != end else { return 0 }
        return end > start ? end - start : 24 * 60 - start + end
    }

    var hasSelectedWeekday: Bool {
        !weekdays.isEmpty
    }

    func isActive(onWeekday weekday: Int) -> Bool {
        weekdays.contains(weekday)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let currentMinute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinuteOfDay = startHour * 60 + startMinute
        let endMinuteOfDay = endHour * 60 + endMinute
        let weekday = calendar.component(.weekday, from: date)

        guard startMinuteOfDay != endMinuteOfDay else { return false }
        if startMinuteOfDay < endMinuteOfDay {
            guard isActive(onWeekday: weekday) else { return false }
            return currentMinute >= startMinuteOfDay && currentMinute < endMinuteOfDay
        }
        if currentMinute >= startMinuteOfDay {
            return isActive(onWeekday: weekday)
        }
        if currentMinute < endMinuteOfDay {
            return isActive(onWeekday: Self.previousWeekday(weekday))
        }
        return false
    }

    func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: date)
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let candidate = calendar.date(
                    bySettingHour: startHour,
                    minute: startMinute,
                    second: 0,
                    of: day
                  ) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: candidate)
            if isActive(onWeekday: weekday), candidate > date {
                return candidate
            }
        }
        return nil
    }

    static func previousWeekday(_ weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }
}

enum ScreenTimeScheduleValidationError: LocalizedError, Equatable {
    case intervalTooShort(title: String)
    case tooManyEnabledSlots(maximum: Int)
    case invalidDailyTicketMinutes

    var errorDescription: String? {
        switch self {
        case .intervalTooShort(let title):
            return "\(title)は15分以上の時間帯を指定してください"
        case .tooManyEnabledSlots(let maximum):
            return "有効にできる時間帯は最大\(maximum)件です"
        case .invalidDailyTicketMinutes:
            return "1日の利用時間は0〜1440分の10分刻みで指定してください"
        }
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
        dayStart == ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: date))
    }

    func unlocksRestrictions(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        isForDay(containing: date, calendar: calendar) && hasReachedTarget
    }
}

struct ScreenTimeRuntimeState: Codable, Equatable {
    var timerIsRunning: Bool
    /// Epoch milliseconds for an automatically ending countdown timer.
    /// `nil` means the running timer has no automatic end (for example, a stopwatch).
    var timerRestrictionEndsAt: Int64?
    var updatedAt: Int64

    init(
        timerIsRunning: Bool = false,
        timerRestrictionEndsAt: Int64? = nil,
        updatedAt: Int64 = ScreenTimeDateMath.epochMilliseconds(for: Date())
    ) {
        self.timerIsRunning = timerIsRunning
        self.timerRestrictionEndsAt = timerRestrictionEndsAt
        self.updatedAt = updatedAt
    }

    func isTimerRestrictionActive(at date: Date = Date()) -> Bool {
        guard timerIsRunning else { return false }
        guard let timerRestrictionEndsAt else { return true }
        return ScreenTimeDateMath.epochMilliseconds(for: date) < timerRestrictionEndsAt
    }

    var timerRestrictionEndDate: Date? {
        timerRestrictionEndsAt.map(ScreenTimeDateMath.date(fromEpochMilliseconds:))
    }
}

struct ScreenTimeFocusSettings: Codable, Equatable {
    static let minimumScheduleDurationMinutes = 15
    static let maximumEnabledScheduleSlots = 20
    static let maximumEnabledScheduleSlotsWithTickets = 18
    static let ticketDurationMinutes = 10
    static let minimumDailyTicketMinutes = 0
    static let maximumDailyTicketMinutes = 1_440

    var isEnabled: Bool
    var timerRestrictionEnabled: Bool
    var scheduledRestrictionEnabled: Bool
    var ticketRestrictionEnabled: Bool
    var dailyTicketMinutes: Int
    var restrictOutsideScheduleWhenTicketsDisabled: Bool
    var unlockRestrictionsWhenDailyGoalReached: Bool
    var scheduleSlots: [FocusScheduleSlot]
    var activitySelection: FamilyActivitySelection
    /// Whether the user selected device-local Family Controls tokens.
    /// The tokens themselves are intentionally never synced between devices.
    var selectionWasConfigured: Bool
    /// Last time a cloud-portable Screen Time setting changed.
    var updatedAt: Int64
    /// Epoch milliseconds. While `Date() < expiry`, all Screen Time settings are read-only in-app.
    var settingsLockedUntilEpochMilliseconds: Int64?

    init(
        isEnabled: Bool = false,
        timerRestrictionEnabled: Bool = false,
        scheduledRestrictionEnabled: Bool = false,
        ticketRestrictionEnabled: Bool = false,
        dailyTicketMinutes: Int = 0,
        restrictOutsideScheduleWhenTicketsDisabled: Bool = false,
        unlockRestrictionsWhenDailyGoalReached: Bool = false,
        scheduleSlots: [FocusScheduleSlot] = [],
        activitySelection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true),
        selectionWasConfigured: Bool? = nil,
        updatedAt: Int64 = 0,
        settingsLockedUntilEpochMilliseconds: Int64? = nil
    ) {
        self.isEnabled = isEnabled
        self.timerRestrictionEnabled = timerRestrictionEnabled
        self.scheduledRestrictionEnabled = scheduledRestrictionEnabled
        self.ticketRestrictionEnabled = ticketRestrictionEnabled
        self.dailyTicketMinutes = dailyTicketMinutes
        self.restrictOutsideScheduleWhenTicketsDisabled = restrictOutsideScheduleWhenTicketsDisabled
        self.unlockRestrictionsWhenDailyGoalReached = unlockRestrictionsWhenDailyGoalReached
        self.scheduleSlots = scheduleSlots
        self.activitySelection = Self.selectionIncludingEntireCategories(activitySelection)
        self.selectionWasConfigured = selectionWasConfigured
            ?? !activitySelection.applicationTokens.isEmpty
            || !activitySelection.webDomainTokens.isEmpty
        self.updatedAt = updatedAt
        self.settingsLockedUntilEpochMilliseconds = settingsLockedUntilEpochMilliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case timerRestrictionEnabled
        case scheduledRestrictionEnabled
        case ticketRestrictionEnabled
        case dailyTicketMinutes
        case restrictOutsideScheduleWhenTicketsDisabled
        case unlockRestrictionsWhenDailyGoalReached
        case scheduleSlots
        case activitySelection
        case selectionWasConfigured
        case updatedAt
        case settingsLockedUntilEpochMilliseconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        timerRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .timerRestrictionEnabled) ?? false
        scheduledRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduledRestrictionEnabled) ?? false
        ticketRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .ticketRestrictionEnabled) ?? false
        dailyTicketMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyTicketMinutes) ?? 0
        restrictOutsideScheduleWhenTicketsDisabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .restrictOutsideScheduleWhenTicketsDisabled
        ) ?? false
        unlockRestrictionsWhenDailyGoalReached = try container.decodeIfPresent(
            Bool.self,
            forKey: .unlockRestrictionsWhenDailyGoalReached
        ) ?? false
        scheduleSlots = try container.decodeIfPresent([FocusScheduleSlot].self, forKey: .scheduleSlots) ?? []
        let decodedSelection = try container.decodeIfPresent(
            FamilyActivitySelection.self,
            forKey: .activitySelection
        ) ?? FamilyActivitySelection(includeEntireCategory: true)
        activitySelection = Self.selectionIncludingEntireCategories(decodedSelection)
        selectionWasConfigured = try container.decodeIfPresent(
            Bool.self,
            forKey: .selectionWasConfigured
        ) ?? (!decodedSelection.applicationTokens.isEmpty || !decodedSelection.webDomainTokens.isEmpty)
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        settingsLockedUntilEpochMilliseconds = try container.decodeIfPresent(
            Int64.self,
            forKey: .settingsLockedUntilEpochMilliseconds
        )
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

    var hasMeaningfulConfiguration: Bool {
        isEnabled
            || timerRestrictionEnabled
            || scheduledRestrictionEnabled
            || ticketRestrictionEnabled
            || dailyTicketMinutes != 0
            || restrictOutsideScheduleWhenTicketsDisabled
            || unlockRestrictionsWhenDailyGoalReached
            || !scheduleSlots.isEmpty
            || selectionWasConfigured
            || settingsLockedUntilEpochMilliseconds != nil
    }

    var enabledScheduleSlots: [FocusScheduleSlot] {
        guard isEnabled, scheduledRestrictionEnabled else { return [] }
        return scheduleSlots.filter { $0.isEnabled && $0.hasSelectedWeekday }
    }

    var maximumEnabledSlotsForCurrentConfiguration: Int {
        Self.maximumEnabledScheduleSlots - reservedMonitoringActivityCount
    }

    var requiresDailyBoundaryMonitoring: Bool {
        isEnabled && (ticketRestrictionEnabled || unlockRestrictionsWhenDailyGoalReached)
    }

    private var reservedMonitoringActivityCount: Int {
        guard isEnabled else { return 0 }
        var count = 0
        if ticketRestrictionEnabled || unlockRestrictionsWhenDailyGoalReached {
            count += 1
        }
        guard !unlockRestrictionsWhenDailyGoalReached else { return count }
        if ticketRestrictionEnabled {
            count += 1
        }
        if timerRestrictionEnabled {
            count += 1
        }
        return count
    }

    func validateMonitoringConfiguration() throws {
        guard (Self.minimumDailyTicketMinutes...Self.maximumDailyTicketMinutes).contains(dailyTicketMinutes),
              dailyTicketMinutes.isMultiple(of: Self.ticketDurationMinutes) else {
            throw ScreenTimeScheduleValidationError.invalidDailyTicketMinutes
        }
        let slots = enabledScheduleSlots
        let maximum = maximumEnabledSlotsForCurrentConfiguration
        guard slots.count <= maximum else {
            throw ScreenTimeScheduleValidationError.tooManyEnabledSlots(maximum: maximum)
        }
        if let invalidSlot = slots.first(where: {
            $0.durationMinutes < Self.minimumScheduleDurationMinutes
        }) {
            throw ScreenTimeScheduleValidationError.intervalTooShort(title: invalidSlot.title)
        }
    }

    func validateScheduleMonitoringConfiguration() throws {
        try validateMonitoringConfiguration()
    }

    mutating func normalizeActivitySelection() {
        activitySelection = Self.selectionIncludingEntireCategories(activitySelection)
    }

    var canApplyRestrictions: Bool {
        isEnabled && (!allowedApplicationTokens.isEmpty || !allowedWebDomainTokens.isEmpty)
    }

    var requiresAllowedSelection: Bool {
        guard isEnabled else { return false }
        if timerRestrictionEnabled || ticketRestrictionEnabled {
            return true
        }
        guard scheduledRestrictionEnabled else { return false }
        return restrictOutsideScheduleWhenTicketsDisabled
            || enabledScheduleSlots.contains(where: { $0.behavior == .block })
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

    func nextAllowedScheduleStart(
        after date: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        enabledScheduleSlots
            .filter { $0.behavior == .allow }
            .compactMap { $0.nextStart(after: date, calendar: calendar) }
            .min()
    }

    private static func selectionIncludingEntireCategories(
        _ selection: FamilyActivitySelection
    ) -> FamilyActivitySelection {
        guard !selection.includeEntireCategory else { return selection }
        var normalized = FamilyActivitySelection(includeEntireCategory: true)
        normalized.applicationTokens = selection.applicationTokens
        normalized.categoryTokens = selection.categoryTokens
        normalized.webDomainTokens = selection.webDomainTokens
        return normalized
    }
}

/// Cloud-portable Screen Time policy. Family Controls tokens are deliberately
/// excluded because Apple treats them as opaque, device-local authorization data.
struct ScreenTimeSyncSettings: Codable, Hashable {
    static let stableSyncId = "screen-time-focus"

    var syncId: String
    var isEnabled: Bool
    var timerRestrictionEnabled: Bool
    var scheduledRestrictionEnabled: Bool
    var ticketRestrictionEnabled: Bool
    var dailyTicketMinutes: Int
    var restrictOutsideScheduleWhenTicketsDisabled: Bool
    var unlockRestrictionsWhenDailyGoalReached: Bool
    var scheduleSlots: [FocusScheduleSlot]
    var selectionWasConfigured: Bool
    var settingsLockedUntilEpochMilliseconds: Int64?
    var updatedAt: Int64
    var deletedAt: Int64?

    init(settings: ScreenTimeFocusSettings) {
        syncId = Self.stableSyncId
        isEnabled = settings.isEnabled
        timerRestrictionEnabled = settings.timerRestrictionEnabled
        scheduledRestrictionEnabled = settings.scheduledRestrictionEnabled
        ticketRestrictionEnabled = settings.ticketRestrictionEnabled
        dailyTicketMinutes = settings.dailyTicketMinutes
        restrictOutsideScheduleWhenTicketsDisabled = settings.restrictOutsideScheduleWhenTicketsDisabled
        unlockRestrictionsWhenDailyGoalReached = settings.unlockRestrictionsWhenDailyGoalReached
        scheduleSlots = settings.scheduleSlots
        selectionWasConfigured = settings.selectionWasConfigured
        settingsLockedUntilEpochMilliseconds = settings.settingsLockedUntilEpochMilliseconds
        updatedAt = settings.updatedAt
        deletedAt = nil
    }

    var requiresAllowedSelection: Bool {
        guard isEnabled else { return false }
        if timerRestrictionEnabled || ticketRestrictionEnabled {
            return true
        }
        guard scheduledRestrictionEnabled else { return false }
        return restrictOutsideScheduleWhenTicketsDisabled
            || scheduleSlots.contains { $0.isEnabled && $0.behavior == .block && $0.hasSelectedWeekday }
    }

    func restoredSettings(preserving selection: FamilyActivitySelection) -> ScreenTimeFocusSettings {
        ScreenTimeFocusSettings(
            isEnabled: isEnabled,
            timerRestrictionEnabled: timerRestrictionEnabled,
            scheduledRestrictionEnabled: scheduledRestrictionEnabled,
            ticketRestrictionEnabled: ticketRestrictionEnabled,
            dailyTicketMinutes: dailyTicketMinutes,
            restrictOutsideScheduleWhenTicketsDisabled: restrictOutsideScheduleWhenTicketsDisabled,
            unlockRestrictionsWhenDailyGoalReached: unlockRestrictionsWhenDailyGoalReached,
            scheduleSlots: scheduleSlots,
            activitySelection: selection,
            selectionWasConfigured: selectionWasConfigured,
            updatedAt: updatedAt,
            settingsLockedUntilEpochMilliseconds: settingsLockedUntilEpochMilliseconds
        )
    }

    func requiresSelectionConfirmation(preserving selection: FamilyActivitySelection) -> Bool {
        let hasLocalSelection = !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty
        return !hasLocalSelection && (selectionWasConfigured || requiresAllowedSelection)
    }
}

enum ScreenTimePolicyReason: String, Codable, Equatable {
    case masterDisabled
    case dailyGoalPending
    case dailyGoalReached
    case studyTimer
    case blockedSchedule
    case allowedSchedule
    case activeTicket
    case ticketRequired
    case outsideScheduleBlocked
    case unrestricted
}

struct ScreenTimePolicyDecision: Equatable {
    var isRestricted: Bool
    var reason: ScreenTimePolicyReason

    var canStartTicket: Bool {
        isRestricted && reason == .ticketRequired
    }
}

enum ScreenTimePolicyEvaluator {
    static func evaluate(
        settings: ScreenTimeFocusSettings,
        ledger: ScreenTimeTicketLedger?,
        dailyGoalProgress: ScreenTimeDailyGoalProgress?,
        runtimeState: ScreenTimeRuntimeState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> ScreenTimePolicyDecision {
        guard settings.isEnabled else {
            return ScreenTimePolicyDecision(isRestricted: false, reason: .masterDisabled)
        }
        if settings.unlockRestrictionsWhenDailyGoalReached {
            if settings.shouldUnlockRestrictionsForDailyGoal(
                progress: dailyGoalProgress,
                referenceDate: referenceDate,
                calendar: calendar
            ) {
                return ScreenTimePolicyDecision(isRestricted: false, reason: .dailyGoalReached)
            }
            return ScreenTimePolicyDecision(isRestricted: true, reason: .dailyGoalPending)
        }
        if settings.timerRestrictionEnabled,
           runtimeState.isTimerRestrictionActive(at: referenceDate) {
            return ScreenTimePolicyDecision(isRestricted: true, reason: .studyTimer)
        }

        let activeSlots = settings.activeScheduleSlots(at: referenceDate, calendar: calendar)
        if activeSlots.contains(where: { $0.behavior == .block }) {
            return ScreenTimePolicyDecision(isRestricted: true, reason: .blockedSchedule)
        }
        if activeSlots.contains(where: { $0.behavior == .allow }) {
            return ScreenTimePolicyDecision(isRestricted: false, reason: .allowedSchedule)
        }

        if settings.ticketRestrictionEnabled {
            if ledger?.hasActiveTicket(at: referenceDate, calendar: calendar) == true {
                return ScreenTimePolicyDecision(isRestricted: false, reason: .activeTicket)
            }
            return ScreenTimePolicyDecision(isRestricted: true, reason: .ticketRequired)
        }

        if settings.scheduledRestrictionEnabled,
           settings.restrictOutsideScheduleWhenTicketsDisabled {
            return ScreenTimePolicyDecision(isRestricted: true, reason: .outsideScheduleBlocked)
        }

        return ScreenTimePolicyDecision(isRestricted: false, reason: .unrestricted)
    }
}

enum ScreenTimeRestrictionApplyResult: Equatable {
    case inactive
    case missingAllowedSelection
    case applied
}

enum ScreenTimeFocusShared {
    static let appGroupIdentifier = "group.com.studyapp.ios.shared"
    static let settingsKey = "screenTimeFocusSettings.v1"
    static let dailyGoalProgressKey = "screenTimeFocusDailyGoalProgress.v1"
    static let runtimeStateKey = "screenTimeRuntimeState.v1"
    static let restoredSelectionRequiredKey = "screenTimeFocusRestoredSelectionRequired.v1"
    static let scheduleActivityNamePrefix = "studyapp.focus.schedule."
    static let dailyBoundaryActivityName = DeviceActivityName("studyapp.focus.daily-boundary")
    static let ticketExpiryActivityName = DeviceActivityName("studyapp.focus.ticket-expiry")
    static let timerExpiryActivityName = DeviceActivityName("studyapp.focus.timer-expiry")
    static let policyStoreName = ManagedSettingsStore.Name("studyapp.focus.policy")
    static let legacyTimerStoreName = ManagedSettingsStore.Name("studyapp.focus.timer")
    static let legacyScheduleStoreName = ManagedSettingsStore.Name("studyapp.focus.schedule")

    static var allScheduleActivityNames: [DeviceActivityName] {
        loadSettings().scheduleSlots.map(\.activityName)
    }

    static func loadSettings() -> ScreenTimeFocusSettings {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: settingsKey),
              var settings = try? JSONDecoder().decode(ScreenTimeFocusSettings.self, from: data) else {
            return ScreenTimeFocusSettings()
        }
        if settings.updatedAt == 0, settings.hasMeaningfulConfiguration {
            settings.updatedAt = ScreenTimeDateMath.epochMilliseconds(for: Date())
            if let migrated = try? JSONEncoder().encode(settings) {
                defaults.set(migrated, forKey: settingsKey)
            }
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

    static func loadSyncSettings() -> ScreenTimeSyncSettings? {
        let settings = loadSettings()
        guard settings.updatedAt > 0, settings.hasMeaningfulConfiguration else { return nil }
        return ScreenTimeSyncSettings(settings: settings)
    }

    @discardableResult
    static func applySyncedSettings(_ synced: ScreenTimeSyncSettings) -> Bool {
        let current = loadSettings()
        let requiresSelection = synced.requiresSelectionConfirmation(
            preserving: current.activitySelection
        )
        let restored = synced.restoredSettings(preserving: current.activitySelection)
        guard saveSettings(restored),
              let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return false
        }
        defaults.set(requiresSelection, forKey: restoredSelectionRequiredKey)
        return true
    }

    static var isRestoredSelectionRequired: Bool {
        UserDefaults(suiteName: appGroupIdentifier)?
            .bool(forKey: restoredSelectionRequiredKey) == true
    }

    static func setRestoredSelectionRequired(_ required: Bool) {
        UserDefaults(suiteName: appGroupIdentifier)?
            .set(required, forKey: restoredSelectionRequiredKey)
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

    static func loadRuntimeState() -> ScreenTimeRuntimeState {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: runtimeStateKey),
              let state = try? JSONDecoder().decode(ScreenTimeRuntimeState.self, from: data) else {
            return ScreenTimeRuntimeState()
        }
        return state
    }

    @discardableResult
    static func saveRuntimeState(_ state: ScreenTimeRuntimeState) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(state) else {
            return false
        }
        defaults.set(data, forKey: runtimeStateKey)
        return true
    }

    static func applyRestrictions(
        using store: ManagedSettingsStore,
        settings: ScreenTimeFocusSettings
    ) -> ScreenTimeRestrictionApplyResult {
        guard settings.isEnabled else {
            clearRestrictions(using: store)
            return .inactive
        }
        guard settings.canApplyRestrictions else {
            clearRestrictions(using: store)
            return .missingAllowedSelection
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
