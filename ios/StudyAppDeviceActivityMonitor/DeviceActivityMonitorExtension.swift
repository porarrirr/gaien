import DeviceActivity
import ManagedSettings

final class StudyAppDeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let scheduleStore = ManagedSettingsStore(named: ScreenTimeFocusShared.scheduleStoreName)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let settings = ScreenTimeFocusShared.loadSettings()
        _ = ScreenTimeFocusShared.applyRestrictions(using: scheduleStore, settings: settings)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let settings = ScreenTimeFocusShared.loadSettings()
        if settings.hasActiveScheduleSlot() {
            _ = ScreenTimeFocusShared.applyRestrictions(using: scheduleStore, settings: settings)
        } else {
            ScreenTimeFocusShared.clearRestrictions(using: scheduleStore)
        }
    }
}
