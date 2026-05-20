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
}

struct ScreenTimeFocusSettings: Codable, Equatable {
    var isEnabled: Bool
    var timerRestrictionEnabled: Bool
    var scheduledRestrictionEnabled: Bool
    var scheduleSlots: [FocusScheduleSlot]
    var activitySelection: FamilyActivitySelection

    init(
        isEnabled: Bool = false,
        timerRestrictionEnabled: Bool = false,
        scheduledRestrictionEnabled: Bool = false,
        scheduleSlots: [FocusScheduleSlot] = [],
        activitySelection: FamilyActivitySelection = FamilyActivitySelection()
    ) {
        self.isEnabled = isEnabled
        self.timerRestrictionEnabled = timerRestrictionEnabled
        self.scheduledRestrictionEnabled = scheduledRestrictionEnabled
        self.scheduleSlots = scheduleSlots
        self.activitySelection = activitySelection
    }

    var allowedApplicationTokens: Set<ApplicationToken> {
        activitySelection.applicationTokens
    }

    var enabledScheduleSlots: [FocusScheduleSlot] {
        guard isEnabled, scheduledRestrictionEnabled else { return [] }
        return scheduleSlots.filter(\.isEnabled)
    }

    var canApplyRestrictions: Bool {
        isEnabled && !allowedApplicationTokens.isEmpty
    }
}

enum ScreenTimeFocusShared {
    static let appGroupIdentifier = "group.com.studyapp.ios.shared"
    static let settingsKey = "screenTimeFocusSettings.v1"
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

    static func applyRestrictions(using store: ManagedSettingsStore, settings: ScreenTimeFocusSettings) -> Bool {
        guard settings.canApplyRestrictions else {
            clearRestrictions(using: store)
            return false
        }
        store.shield.applicationCategories = .all(except: settings.allowedApplicationTokens)
        return true
    }

    static func clearRestrictions(using store: ManagedSettingsStore) {
        store.shield.applicationCategories = nil
        store.shield.applications = nil
        store.shield.webDomainCategories = nil
        store.shield.webDomains = nil
    }
}
