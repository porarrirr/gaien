import ManagedSettings
import ManagedSettingsUI
import OSLog
import UIKit

final class StudyAppShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let logger = Logger(
        subsystem: "com.studyapp.ios",
        category: "ShieldConfiguration"
    )

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration(referenceDate: Date = Date()) -> ShieldConfiguration {
        let settings = ScreenTimeFocusShared.loadSettings()
        let ledger = loadLedger(settings: settings, referenceDate: referenceDate)
        let decision = ScreenTimePolicyEvaluator.evaluate(
            settings: settings,
            ledger: ledger,
            dailyGoalProgress: ScreenTimeFocusShared.loadDailyGoalProgress(),
            runtimeState: ScreenTimeFocusShared.loadRuntimeState(),
            referenceDate: referenceDate
        )
        let remaining = ledger?.isForDay(containing: referenceDate) == true
            ? ledger?.remainingTicketCount ?? 0
            : 0
        let canStartTicket = decision.canStartTicket && remaining > 0

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.82),
            icon: UIImage(systemName: canStartTicket ? "ticket.fill" : "lock.shield.fill"),
            title: ShieldConfiguration.Label(
                text: title(for: decision.reason),
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle(
                    settings: settings,
                    decision: decision,
                    remainingTickets: decision.canStartTicket ? remaining : nil,
                    referenceDate: referenceDate
                ),
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: canStartTicket ? "10分チケットを使う" : "閉じる",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: canStartTicket ? UIColor.systemGreen : UIColor.systemGray,
            secondaryButtonLabel: canStartTicket
                ? ShieldConfiguration.Label(text: "閉じる", color: UIColor.secondaryLabel)
                : nil
        )
    }

    /// 表示専用なので協調書き込みを伴わない読み取り経路を使う。
    /// 読めなかった場合と「本当に0枚」を区別できるよう、失敗は必ずログに残す。
    private func loadLedger(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date
    ) -> ScreenTimeTicketLedger? {
        do {
            return try ScreenTimeTicketLedgerStore().loadReadOnly(
                settings: settings,
                referenceDate: referenceDate
            )
        } catch {
            logger.error(
                "Failed to read ticket ledger for shield: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func title(for reason: ScreenTimePolicyReason) -> String {
        switch reason {
        case .dailyGoalPending:
            return "学習目標が未達成です"
        case .studyTimer:
            return "学習タイマー中です"
        case .blockedSchedule:
            return "使用禁止時間帯です"
        case .ticketRequired:
            return "チケットが必要です"
        case .outsideScheduleBlocked:
            return "利用時間外です"
        case .activeTicket:
            return "チケットを確認しています"
        case .dailyGoalReached, .allowedSchedule, .masterDisabled, .unrestricted:
            return "まもなく利用できます"
        }
    }

    /// `remainingTickets` が nil のときは、この状態でチケットが使えない
    /// （チケット制がオフ、またはチケットで解除できない理由）ことを表す。
    /// その場合は枚数にも「チケットで解除できます」にも言及しない。
    private func subtitle(
        settings: ScreenTimeFocusSettings,
        decision: ScreenTimePolicyDecision,
        remainingTickets: Int?,
        referenceDate: Date
    ) -> String {
        guard let remainingTickets else {
            return subtitleWithoutTickets(
                reason: decision.reason,
                settings: settings,
                referenceDate: referenceDate
            )
        }
        guard remainingTickets > 0 else {
            return "今日使えるチケットは残っていません。\(subtitleWithoutTickets(reason: decision.reason, settings: settings, referenceDate: referenceDate))"
        }
        switch decision.reason {
        case .dailyGoalPending:
            return "今日の残りは\(remainingTickets)枚です。チケット1枚で目標未達成の制限を10分間解除できます。"
        case .ticketRequired:
            return "今日の残りは\(remainingTickets)枚です。1枚で10分間利用できます。\(nextFreeOpeningText(settings: settings, after: referenceDate))"
        case .studyTimer:
            return "今日の残りは\(remainingTickets)枚です。チケット1枚でタイマー中の制限を10分間解除できます。"
        case .blockedSchedule:
            if let nextStart = settings.nextAllowedScheduleStart(after: referenceDate) {
                return "今日の残りは\(remainingTickets)枚です。チケットで10分間解除できます。次の無料開放は\(Self.dateFormatter.string(from: nextStart))です。"
            }
            return "今日の残りは\(remainingTickets)枚です。チケット1枚でこの制限を10分間解除できます。"
        default:
            return "制限状態を更新しています。"
        }
    }

    private func subtitleWithoutTickets(
        reason: ScreenTimePolicyReason,
        settings: ScreenTimeFocusSettings,
        referenceDate: Date
    ) -> String {
        switch reason {
        case .dailyGoalPending:
            return "今日の学習目標を達成すると、終日利用できます。"
        case .studyTimer:
            return "学習タイマーが終了するまで利用できません。"
        case .ticketRequired, .blockedSchedule, .outsideScheduleBlocked:
            return nextFreeOpeningText(settings: settings, after: referenceDate)
        default:
            return "制限状態を更新しています。"
        }
    }

    private func nextFreeOpeningText(
        settings: ScreenTimeFocusSettings,
        after referenceDate: Date
    ) -> String {
        guard let nextStart = settings.nextAllowedScheduleStart(after: referenceDate) else {
            return "次の無料開放時間は設定されていません。"
        }
        return "次の無料開放は\(Self.dateFormatter.string(from: nextStart))です。"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d H:mm"
        return formatter
    }()
}
