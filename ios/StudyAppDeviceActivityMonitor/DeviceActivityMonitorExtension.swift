import DeviceActivity
import ManagedSettings

final class StudyAppDeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let scheduleStore = ManagedSettingsStore(named: ScreenTimeFocusShared.scheduleStoreName)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        refreshScheduleRestrictions()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        refreshScheduleRestrictions()
    }

    /// Schedules repeat daily, so an interval also fires on weekdays a slot is not meant to
    /// apply to. Re-evaluate the currently active slots (which are weekday-aware) and only
    /// shield when at least one slot applies right now.
    private func refreshScheduleRestrictions() {
        let settings = ScreenTimeFocusShared.loadSettings()
        if settings.hasActiveScheduleSlot() {
            _ = ScreenTimeFocusShared.applyRestrictions(using: scheduleStore, settings: settings)
        } else {
            ScreenTimeFocusShared.clearRestrictions(using: scheduleStore)
        }
    }
}
