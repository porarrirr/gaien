import ManagedSettings
import OSLog

final class StudyAppShieldActionExtension: ShieldActionDelegate {
    private let accessEngine = ScreenTimeAccessEngine()
    private let logger = Logger(
        subsystem: "com.studyapp.ios",
        category: "ShieldAction"
    )

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    private func handle(
        action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            do {
                let snapshot = try accessEngine.snapshot()
                guard snapshot.decision.canStartTicket,
                      snapshot.ledger?.remainingTicketCount ?? 0 > 0 else {
                    completionHandler(.close)
                    return
                }
                _ = try accessEngine.startTicket()
                completionHandler(.defer)
            } catch {
                logger.error(
                    "Shield ticket start failed: \(error.localizedDescription, privacy: .public)"
                )
                completionHandler(.defer)
            }
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.none)
        }
    }
}
