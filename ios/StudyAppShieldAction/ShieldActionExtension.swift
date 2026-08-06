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
        // 制限にぶつかった回数を残す。シールドの表示回数は取得できないため、
        // 実際に操作されたときだけを集計する（週次レポートでもその旨を示す）。
        accessEngine.recordShieldInteraction()

        switch action {
        case .primaryButtonPressed:
            do {
                let snapshot = try accessEngine.snapshot()
                let settings = ScreenTimeFocusShared.loadSettings()
                guard snapshot.decision.canStartTicket,
                      let ledger = snapshot.ledger,
                      ledger.remainingTicketCount > 0,
                      !ledger.isInTicketCooldown(at: Date(), settings: settings) else {
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
        default:
            // iOS 26.4 で追加されたサブメニュー項目など。この拡張はサブメニューを
            // 構成しないため届かない想定だが、届いても画面は閉じずに何もしない。
            // （案内された古い `@unknown default` は、SDK 側の新しい既知ケースを
            // 網羅していないという警告を消せない。）
            completionHandler(.none)
        }
    }
}
