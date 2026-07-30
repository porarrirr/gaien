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
        // 期限監視はウィンドウの「開始」が期限到達を表す。
        guard isExpiryActivity(activity) else {
            refreshRestrictions(event: "start", activity: activity)
            return
        }
        if activity == ScreenTimeFocusShared.ticketExpiryActivityName {
            finalizeExpiredTicket(activity: activity)
        }
        refreshRestrictions(event: "expiry", activity: activity)
        // 再適用が済んでから監視を解除する。逆順だと、解除と再適用の間で拡張が落ちたときに
        // 「監視も解除済み・シールドも無し」で確定してしまう。
        accessEngine.completeOneShotMonitoring(activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        refreshRestrictions(event: "end", activity: activity)
        accessEngine.completeOneShotMonitoring(activity)
    }

    private func isExpiryActivity(_ activity: DeviceActivityName) -> Bool {
        activity == ScreenTimeFocusShared.ticketExpiryActivityName
            || activity == ScreenTimeFocusShared.timerExpiryActivityName
    }

    private func finalizeExpiredTicket(activity: DeviceActivityName) {
        do {
            let finalized = try accessEngine.finalizeExpiredTicket()
            logger.notice(
                "Finalized expired ticket for \(activity.rawValue, privacy: .public): \(finalized, privacy: .public)"
            )
        } catch {
            logger.error(
                "Failed to finalize expired ticket: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func refreshRestrictions(event: String, activity: DeviceActivityName) {
        do {
            let decision = try accessEngine.applyCurrentPolicy()
            logger.notice(
                """
                Refreshed Screen Time policy for \(activity.rawValue, privacy: .public) \
                \(event, privacy: .public): restricted=\(decision.isRestricted, privacy: .public) \
                reason=\(decision.reason.rawValue, privacy: .public)
                """
            )
        } catch {
            logger.error(
                "Failed to refresh Screen Time policy for \(activity.rawValue, privacy: .public) \(event, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
