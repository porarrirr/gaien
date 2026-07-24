import DeviceActivity
import OSLog

final class StudyAppDeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let accessEngine = ScreenTimeAccessEngine()
    private let logger = Logger(
        subsystem: "com.studyapp.ios",
        category: "DeviceActivityMonitor"
    )

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        refreshRestrictions(event: "start", activity: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        refreshRestrictions(event: "end", activity: activity)
    }

    private func refreshRestrictions(event: String, activity: DeviceActivityName) {
        do {
            _ = try accessEngine.applyCurrentPolicy()
            logger.notice(
                "Refreshed Screen Time policy for \(activity.rawValue, privacy: .public) \(event, privacy: .public)"
            )
        } catch {
            logger.error(
                "Failed to refresh Screen Time policy: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
