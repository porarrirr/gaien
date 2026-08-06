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
        let isForToday = ledger?.isForDay(containing: referenceDate) == true
        let remaining = isForToday ? ledger?.remainingTicketCount ?? 0 : 0
        let cooldownEnd = ledger?.ticketCooldownEndDate(settings: settings)
        let isCoolingDown = ledger?.isInTicketCooldown(at: referenceDate, settings: settings) == true
        let canStartTicket = decision.canStartTicket && remaining > 0 && !isCoolingDown

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.82),
            icon: UIImage(systemName: iconName(for: decision.reason, canStartTicket: canStartTicket)),
            title: ShieldConfiguration.Label(
                text: title(for: decision.reason, ticketsEnabled: decision.ticketRestrictionEnabled),
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle(
                    settings: settings,
                    ledger: ledger,
                    decision: decision,
                    remainingTickets: remaining,
                    isCoolingDown: isCoolingDown,
                    cooldownEnd: cooldownEnd,
                    referenceDate: referenceDate
                ),
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: canStartTicket ? "\(ScreenTimeFocusSettings.ticketDurationMinutes)分チケットを使う" : "閉じる",
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

    private func iconName(for reason: ScreenTimePolicyReason, canStartTicket: Bool) -> String {
        if canStartTicket {
            return "ticket.fill"
        }
        switch reason {
        case .budgetExhausted:
            return "hourglass.bottomhalf.filled"
        case .lockedSchedule:
            return "moon.zzz.fill"
        case .dailyGoalPending:
            return "target"
        case .studyTimer:
            return "timer"
        default:
            return "lock.shield.fill"
        }
    }

    private func title(for reason: ScreenTimePolicyReason, ticketsEnabled: Bool) -> String {
        switch reason {
        case .budgetExhausted:
            return "今日の持ち時間を使い切りました"
        case .lockedSchedule:
            return "いまは開けられない時間です"
        case .dailyGoalPending:
            return "学習目標が未達成です"
        case .studyTimer:
            return "学習タイマー中です"
        case .blockedSchedule:
            return "使用禁止時間帯です"
        case .alwaysRestricted:
            // チケットが無効なら「チケットが必要」は誤誘導になる。
            return ticketsEnabled ? "チケットが必要です" : "いまは使えません"
        case .activeTicket:
            return "チケットを確認しています"
        case .dailyGoalReached, .allowedSchedule, .masterDisabled, .unrestricted:
            return "まもなく利用できます"
        }
    }

    private func subtitle(
        settings: ScreenTimeFocusSettings,
        ledger: ScreenTimeTicketLedger?,
        decision: ScreenTimePolicyDecision,
        remainingTickets: Int,
        isCoolingDown: Bool,
        cooldownEnd: Date?,
        referenceDate: Date
    ) -> String {
        // 持ち時間の使い切りはチケットでは開けられない。増やす方法を示す。
        if decision.reason == .budgetExhausted {
            return budgetSubtitle(settings: settings, ledger: ledger)
        }
        if decision.reason == .lockedSchedule {
            return "この時間帯はチケットでも開けられません。\(nextFreeOpeningText(settings: settings, after: referenceDate))"
        }

        let reasonText = reasonSubtitle(
            reason: decision.reason,
            settings: settings,
            referenceDate: referenceDate
        )
        guard decision.ticketRestrictionEnabled, decision.isTicketBypassable else {
            return reasonText
        }
        if isCoolingDown, let cooldownEnd {
            return "\(reasonText)次のチケットは\(Self.timeFormatter.string(from: cooldownEnd))から使えます。"
        }
        guard remainingTickets > 0 else {
            return "今日使えるチケットは残っていません。\(reasonText)"
        }
        return "チケット\(remainingTickets)枚。1枚で\(ScreenTimeFocusSettings.ticketDurationMinutes)分だけ開けられます。\(reasonText)"
    }

    private func budgetSubtitle(
        settings: ScreenTimeFocusSettings,
        ledger: ScreenTimeTicketLedger?
    ) -> String {
        let total = ledger?.totalAllowanceMinutes ?? settings.baseAllowanceMinutes
        var text = "今日の枠は\(total)分でした。チケットでは開けられません。"
        if settings.earnedAllowanceEnabled, settings.studyMinutesPerEarnedMinute > 0 {
            let per = settings.studyMinutesPerEarnedMinute
            let earned = ledger?.earnedAllowanceMinutes ?? 0
            let cap = max(settings.earnedAllowanceCapMinutes, 0)
            if earned < cap {
                text += "勉強\(per)分ごとに1分増えます（あと最大\(cap - earned)分）。"
            } else {
                text += "今日稼げる分は上限に達しています。"
            }
        } else {
            text += "明日また使えます。"
        }
        return text
    }

    private func reasonSubtitle(
        reason: ScreenTimePolicyReason,
        settings: ScreenTimeFocusSettings,
        referenceDate: Date
    ) -> String {
        switch reason {
        case .dailyGoalPending:
            return "今日の学習目標を達成すると解除されます。"
        case .studyTimer:
            return "学習タイマーが終了すると解除されます。"
        case .blockedSchedule, .alwaysRestricted:
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
            return "無料開放の時間帯は設定されていません。"
        }
        return "次の無料開放は\(Self.dateFormatter.string(from: nextStart))です。"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d H:mm"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()
}
