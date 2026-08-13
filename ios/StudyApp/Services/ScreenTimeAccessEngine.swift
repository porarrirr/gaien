import DeviceActivity
import Foundation
import ManagedSettings
import OSLog
import UserNotifications

enum ScreenTimeFocusError: LocalizedError {
    case unavailable
    case authorizationRequired
    case locationAuthorizationRequired
    case locationMonitoringUnavailable
    case missingAllowedApplications
    case missingBudgetTargets
    case settingsSaveFailed
    case settingsRollbackFailed(original: String, rollback: String)
    case goalProgressSaveFailed
    case settingsLocked(until: Date)
    case settingsAlreadyLocked(until: Date)
    case invalidLockDuration

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Screen Time APIはこの環境では利用できません"
        case .authorizationRequired:
            return "Screen Timeの許可が必要です"
        case .locationAuthorizationRequired:
            return "場所の制限には、位置情報の「常に許可」が必要です"
        case .locationMonitoringUnavailable:
            return "この端末では場所による制限を利用できません"
        case .missingAllowedApplications:
            return "許可するアプリを選択してください"
        case .missingBudgetTargets:
            return "時間を決めて使うアプリを選択してください"
        case .settingsSaveFailed:
            return "集中制限の設定を保存できませんでした"
        case .settingsRollbackFailed(let original, let rollback):
            return "集中制限の変更に失敗し、以前の状態にも戻せませんでした（変更: \(original)／復元: \(rollback)）"
        case .goalProgressSaveFailed:
            return "目標達成状態を保存できませんでした"
        case .settingsLocked(let until):
            return "設定は\(Self.lockDateFormatter.string(from: until))まで変更できません"
        case .settingsAlreadyLocked(let until):
            return "設定はすでに\(Self.lockDateFormatter.string(from: until))までロックされています"
        case .invalidLockDuration:
            return "ロック期間は1日以上を指定してください"
        }
    }

    private static let lockDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

struct ScreenTimeAccessSnapshot {
    var ledger: ScreenTimeTicketLedger?
    var decision: ScreenTimePolicyDecision
    var nextAllowedScheduleStart: Date?
    /// 使用中またはクールダウン中に、次のチケットが使えるようになる時刻。
    var nextTicketAvailableDate: Date?
    /// 使用量マイルストーンの段間隔（分）。表示を「目安」と伝えるために使う。
    var usageResolutionMinutes: Int
    var isGoalReached: Bool
}

enum ScreenTimeTicketStartError: LocalizedError, Equatable {
    case ticketsDisabled
    case alreadyUnrestricted
    case activeTicket
    case noTicketsRemaining
    case cooldown(until: Date)
    case nonNegotiable
    case midnightCalculationFailed
    case monitoringFailed

    var errorDescription: String? {
        switch self {
        case .ticketsDisabled:
            return "チケットが有効ではありません"
        case .alreadyUnrestricted:
            return "現在はチケットなしで利用できます"
        case .activeTicket:
            return "使用中のチケットが終了してから次のチケットを使ってください"
        case .noTicketsRemaining:
            return "今日使えるチケットは残っていません"
        case .cooldown(let until):
            return "次のチケットは\(Self.timeFormatter.string(from: until))から使えます"
        case .nonNegotiable:
            return "いまの制限はチケットでは開けられません"
        case .midnightCalculationFailed:
            return "チケットの終了時刻を計算できませんでした"
        case .monitoringFailed:
            return "チケットの終了監視を開始できませんでした"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()
}

/// しきい値到達を記録した結果。通知を出すべきかどうかを含む。
struct ScreenTimeUsageMilestoneOutcome: Equatable {
    var didAdvance: Bool
    var totalAllowanceMinutes: Int
    var remainingMinutes: Int
    var isExhausted: Bool
    var shouldNotifyWarning: Bool
    var shouldNotifyExhausted: Bool
}

struct ScreenTimeAccessEngine {
    private static let logger = Logger(
        subsystem: "com.studyapp.ios",
        category: "ScreenTimeAccess"
    )

    private let ledgerStore: ScreenTimeTicketLedgerStore
    private let historyStore: ScreenTimeUsageHistoryStore
    private let deviceActivityCenter: DeviceActivityCenter
    private let policyStore: ManagedSettingsStore
    private let budgetStore: ManagedSettingsStore
    private let legacyTimerStore: ManagedSettingsStore
    private let legacyScheduleStore: ManagedSettingsStore

    init(
        ledgerStore: ScreenTimeTicketLedgerStore = ScreenTimeTicketLedgerStore(),
        historyStore: ScreenTimeUsageHistoryStore = ScreenTimeUsageHistoryStore(),
        deviceActivityCenter: DeviceActivityCenter = DeviceActivityCenter()
    ) {
        // 台帳を正規化するあらゆる経路（起動時の `snapshot` を含む）で、前日分が
        // 上書きされる前に履歴へ切り出す。呼び出し順に依存しないよう、ここで結線する。
        self.ledgerStore = ledgerStore.withStaleDayHandler { stale in
            Self.archive(stale, to: historyStore)
        }
        self.historyStore = historyStore
        self.deviceActivityCenter = deviceActivityCenter
        self.policyStore = ManagedSettingsStore(named: ScreenTimeFocusShared.policyStoreName)
        self.budgetStore = ManagedSettingsStore(named: ScreenTimeFocusShared.budgetStoreName)
        self.legacyTimerStore = ManagedSettingsStore(named: ScreenTimeFocusShared.legacyTimerStoreName)
        self.legacyScheduleStore = ManagedSettingsStore(named: ScreenTimeFocusShared.legacyScheduleStoreName)
    }

    // MARK: - 状態

    func snapshot(referenceDate: Date = Date(), calendar: Calendar = .current) throws -> ScreenTimeAccessSnapshot {
        try snapshot(
            settings: ScreenTimeFocusShared.loadSettings(),
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private func snapshot(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> ScreenTimeAccessSnapshot {
        let ledger = try currentLedger(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar,
            createIfMissing: Self.requiresLedger(settings)
        )
        let progress = ScreenTimeFocusShared.loadDailyGoalProgress()
        let locationPresence = ScreenTimeFocusShared.isLocationMonitoringArmed
            ? ScreenTimeFocusShared.loadLocationPresence()
            : ScreenTimeLocationPresence()
        let decision = ScreenTimePolicyEvaluator.evaluate(
            settings: settings,
            ledger: ledger,
            dailyGoalProgress: progress,
            runtimeState: ScreenTimeFocusShared.loadRuntimeState(),
            locationPresence: locationPresence,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return ScreenTimeAccessSnapshot(
            ledger: ledger,
            decision: decision,
            nextAllowedScheduleStart: settings.nextAllowedScheduleStart(
                after: referenceDate,
                calendar: calendar
            ),
            nextTicketAvailableDate: ledger?.nextTicketAvailableDate(
                at: referenceDate,
                settings: settings
            ),
            // 実際に登録されている階段の粗さを出す。天井は日内で下げないため、
            // 設定上必要な天井より広い階段が張られていることがある。
            usageResolutionMinutes: ScreenTimeAllowance.milestoneResolutionMinutes(
                maximumMinutes: max(
                    settings.usageLadderCeilingMinutes,
                    ScreenTimeFocusShared.budgetLadderCeilingMinutes
                )
            ),
            isGoalReached: ScreenTimePolicyEvaluator.isGoalReached(
                settings: settings,
                progress: progress,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    /// 直近の利用記録。今日の分は台帳から、過去は履歴ファイルから組み立てる。
    func usageSummary(
        dayCount: Int = 7,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ScreenTimeUsageSummary {
        let settings = ScreenTimeFocusShared.loadSettings()
        let history = try historyStore.loadReadOnly()
        let today = try? ledgerStore.loadReadOnly(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return ScreenTimeUsageSummary.make(
            history: history,
            today: today.map { ScreenTimeDayRecord(ledger: $0, calendar: calendar) },
            dayCount: dayCount,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    // MARK: - 適用

    @discardableResult
    func applyCurrentPolicy(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ScreenTimePolicyDecision {
        clearLegacyStores()
        // 判定と適用で別の設定を読まないよう、一度だけ読んで共有する。
        let settings = ScreenTimeFocusShared.loadSettings()
        let snapshot = try snapshot(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        )

        var pendingError: Error?

        if snapshot.decision.restrictsAllApps {
            let result = ScreenTimeFocusShared.applyRestrictions(
                using: policyStore,
                settings: settings
            )
            if result == .missingAllowedSelection {
                pendingError = ScreenTimeFocusError.missingAllowedApplications
            }
        } else {
            ScreenTimeFocusShared.clearRestrictions(using: policyStore)
        }

        // 持ち時間の壁は別ストア。許可リストの壁と同時に立っても互いを消さない。
        if snapshot.decision.restrictsBudgetTargets {
            let result = ScreenTimeFocusShared.applyBudgetRestrictions(
                using: budgetStore,
                settings: settings
            )
            if result == .missingBudgetSelection, pendingError == nil {
                pendingError = ScreenTimeFocusError.missingBudgetTargets
            }
        } else {
            ScreenTimeFocusShared.clearRestrictions(using: budgetStore)
        }

        if let pendingError {
            throw pendingError
        }
        return snapshot.decision
    }

    // MARK: - 監視

    func syncMonitoring(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        try settings.validateMonitoringConfiguration()
        guard !settings.requiresAllowedSelection || settings.canApplyRestrictions else {
            throw ScreenTimeFocusError.missingAllowedApplications
        }
        guard !settings.requiresBudgetSelection || settings.hasBudgetSelection else {
            throw ScreenTimeFocusError.missingBudgetTargets
        }
        clearLegacyStores()
        // 日付が変わっていれば、台帳を作り直す前に前日分を履歴へ残す。
        _ = try? archiveCompletedDayIfNeeded(referenceDate: referenceDate, calendar: calendar)
        stopScheduleMonitoring()

        guard settings.isEnabled else {
            stopDailyBoundaryMonitoring()
            stopTicketExpiryMonitoring()
            stopTimerExpiryMonitoring()
            stopBudgetMonitoring()
            ScreenTimeFocusShared.setBudgetMonitoringFingerprint(nil)
            ScreenTimeFocusShared.setBudgetLadderCeilingMinutes(nil)
            ScreenTimeFocusShared.clearRestrictions(using: policyStore)
            ScreenTimeFocusShared.clearRestrictions(using: budgetStore)
            return
        }

        if settings.scheduledRestrictionEnabled {
            for slot in settings.enabledScheduleSlots {
                let schedule = DeviceActivitySchedule(
                    intervalStart: slot.startDateComponents,
                    intervalEnd: slot.endDateComponents,
                    repeats: true
                )
                try deviceActivityCenter.startMonitoring(slot.activityName, during: schedule)
            }
        }

        if settings.requiresDailyBoundaryMonitoring {
            try registerDailyBoundaryMonitoring()
        } else {
            stopDailyBoundaryMonitoring()
        }

        try syncBudgetMonitoring(settings: settings, referenceDate: referenceDate, calendar: calendar)

        if settings.ticketsEnabled {
            if let ledger = try currentLedger(
                settings: settings,
                referenceDate: referenceDate,
                calendar: calendar,
                createIfMissing: true
            ), ledger.hasActiveTicket(at: referenceDate, calendar: calendar),
               let expiry = ledger.activeTicketEndDate {
                try registerTicketExpiryMonitoring(expiry: expiry, calendar: calendar)
            } else {
                stopTicketExpiryMonitoring()
            }
        } else {
            stopTicketExpiryMonitoring()
            try cancelActiveTicketIfPresent(
                settings: settings,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }

        try syncTimerExpiryMonitoring(
            settings: settings,
            runtimeState: ScreenTimeFocusShared.loadRuntimeState(),
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    func syncTimerExpiryMonitoring(
        settings: ScreenTimeFocusSettings,
        runtimeState: ScreenTimeRuntimeState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        stopTimerExpiryMonitoring()
        guard settings.isEnabled,
              settings.timerRestrictionEnabled,
              runtimeState.isTimerRestrictionActive(at: referenceDate),
              let expiry = runtimeState.timerRestrictionEndDate else {
            return
        }
        try registerTimerExpiryMonitoring(expiry: expiry, calendar: calendar)
    }

    /// 使用量のしきい値監視を貼る。
    ///
    /// 貼り直すとその区間で積み上がっていた使用量が 0 に戻り、次の段へ向けて
    /// 積み上がっていた端数が失われる。持ち時間を1目盛り動かすたびに貼り直していると、
    /// ステッパーを触るだけで実使用の計測を巻き戻せてしまうため、貼り直すのは
    /// 次の3つの場合だけに限る。
    /// - 監視が失われている（端末再起動など）
    /// - 対象アプリが変わった
    /// - 階段の天井が足りなくなった（持ち時間を増やしたとき）
    ///
    /// 持ち時間を減らす変更では天井が足りているため貼り直さない。段は最適より粗くなるが、
    /// 計測は正しいままで、巻き戻しも起きない。
    private func syncBudgetMonitoring(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar
    ) throws {
        let requiredCeiling = settings.usageLadderCeilingMinutes
        guard settings.requiresBudgetMonitoring, requiredCeiling > 0 else {
            stopBudgetMonitoring()
            ScreenTimeFocusShared.setBudgetMonitoringFingerprint(nil)
            ScreenTimeFocusShared.setBudgetLadderCeilingMinutes(nil)
            return
        }

        let fingerprint = settings.budgetMonitoringFingerprint
        let isMonitoring = deviceActivityCenter.activities.contains(ScreenTimeFocusShared.budgetActivityName)
        let registeredCeiling = ScreenTimeFocusShared.budgetLadderCeilingMinutes
        if isMonitoring,
           ScreenTimeFocusShared.budgetMonitoringFingerprint == fingerprint,
           registeredCeiling >= requiredCeiling {
            return
        }

        // 天井は日内で下げない。下げると階段が変わって貼り直しが必要になるうえ、
        // 一度測れていた範囲を測れなくする理由がない。
        let ceiling = max(requiredCeiling, isMonitoring ? registeredCeiling : 0)
        let milestones = ScreenTimeAllowance.usageMilestones(maximumMinutes: ceiling)
        guard !milestones.isEmpty else {
            stopBudgetMonitoring()
            ScreenTimeFocusShared.setBudgetMonitoringFingerprint(nil)
            ScreenTimeFocusShared.setBudgetLadderCeilingMinutes(nil)
            return
        }

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minutes in milestones {
            events[ScreenTimeFocusShared.usageEventName(minutes: minutes)] = DeviceActivityEvent(
                applications: settings.budgetApplicationTokens,
                categories: settings.budgetCategoryTokens,
                webDomains: settings.budgetWebDomainTokens,
                threshold: DateComponents(minute: minutes)
            )
        }

        stopBudgetMonitoring()
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try deviceActivityCenter.startMonitoring(
            ScreenTimeFocusShared.budgetActivityName,
            during: schedule,
            events: events
        )
        // しきい値の起点が 0 に戻るため、ここまでの記録をベースラインとして固定する。
        // 監視が失われていた場合（端末再起動など）も起点は 0 に戻るので、
        // `isMonitoring` で条件分けせず必ず固定する。当日分が空なら 0 のままで無害。
        try? ledgerStore.update(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        ) { ledger in
            ledger.markUsageMonitoringRestarted()
        }
        ScreenTimeFocusShared.setBudgetMonitoringFingerprint(fingerprint)
        ScreenTimeFocusShared.setBudgetLadderCeilingMinutes(ceiling)
        Self.logger.notice(
            """
            Screen Time budget monitoring registered with \(milestones.count, privacy: .public) \
            thresholds up to \(ceiling, privacy: .public)min
            """
        )
    }

    // MARK: - 使用量

    /// しきい値到達を台帳へ記録する。通知の重複を避けるため、通知済みフラグも同じ更新で立てる。
    @discardableResult
    func recordUsageMilestone(
        minutes: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ScreenTimeUsageMilestoneOutcome {
        let settings = ScreenTimeFocusShared.loadSettings()
        return try ledgerStore.update(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        ) { ledger in
            let didAdvance = ledger.recordUsageMilestone(minutes: minutes)
            let total = ledger.totalAllowanceMinutes
            let remaining = ledger.remainingAllowanceMinutes
            let isExhausted = ledger.isBudgetExhausted(at: referenceDate, calendar: calendar)

            var shouldNotifyExhausted = false
            var shouldNotifyWarning = false
            if isExhausted, !ledger.notifiedUsageExhausted {
                ledger.notifiedUsageExhausted = true
                ledger.notifiedUsageWarning = true
                shouldNotifyExhausted = true
            } else if !isExhausted,
                      total > 0,
                      !ledger.notifiedUsageWarning,
                      Double(remaining) <= Double(total) * ScreenTimeFocusSettings.usageWarningRemainingRatio {
                ledger.notifiedUsageWarning = true
                shouldNotifyWarning = true
            }

            return ScreenTimeUsageMilestoneOutcome(
                didAdvance: didAdvance,
                totalAllowanceMinutes: total,
                remainingMinutes: remaining,
                isExhausted: isExhausted,
                shouldNotifyWarning: shouldNotifyWarning,
                shouldNotifyExhausted: shouldNotifyExhausted
            )
        }
    }

    /// 学習実績にもとづく持ち時間の付与を台帳へ反映する。ホストアプリだけが呼ぶ。
    @discardableResult
    func applyStudyProgress(
        progress: ScreenTimeDailyGoalProgress,
        goalReached: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ScreenTimeTicketLedger {
        let settings = ScreenTimeFocusShared.loadSettings()
        return try ledgerStore.update(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        ) { ledger in
            ledger.applyStudyProgress(progress: progress, settings: settings, goalReached: goalReached)
            return ledger
        }
    }

    /// シールド画面で操作があったことを記録する。
    /// 画面を出しただけでは数えられないため、実際の操作だけを集計する。
    func recordShieldInteraction(referenceDate: Date = Date(), calendar: Calendar = .current) {
        let settings = ScreenTimeFocusShared.loadSettings()
        try? ledgerStore.update(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        ) { ledger in
            ledger.shieldInteractionCount += 1
        }
    }

    /// 制限がオンのままScreen Timeの許可が外れた日を記録する。
    /// シールドはOS側で消えてしまうため、少なくとも記録には残す。
    func recordProtectionInterruption(referenceDate: Date = Date(), calendar: Calendar = .current) {
        let settings = ScreenTimeFocusShared.loadSettings()
        try? ledgerStore.update(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        ) { ledger in
            ledger.protectionInterrupted = true
        }
    }

    /// 日付が変わっていれば、前日の台帳を履歴へ切り出して当日分へ入れ替える。
    ///
    /// 切り出し自体は台帳ストアの日跨ぎフックが行う（`init` で結線している）。
    /// ここは「誰も台帳に触らないまま日が変わった」場合にフックを起動するための入口で、
    /// 日境界の `DeviceActivityMonitor` コールバックから呼ばれる。
    /// - Returns: 切り出す対象があったかどうか。
    @discardableResult
    func archiveCompletedDayIfNeeded(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        guard let raw = try ledgerStore.loadRaw() else { return false }
        let todayOrdinal = ScreenTimeDateMath.localDayOrdinal(for: referenceDate, calendar: calendar)
        guard raw.localDayOrdinal(calendar: calendar) < todayOrdinal else { return false }
        // 正規化経路を通すと、書き戻しの直前にフックが履歴へ切り出す。
        _ = try ledgerStore.load(
            settings: ScreenTimeFocusShared.loadSettings(),
            referenceDate: referenceDate,
            calendar: calendar,
            createIfMissing: false
        )
        return true
    }

    /// 日跨ぎで捨てられる台帳を履歴へ残す。台帳ストアのフックから同期的に呼ばれる。
    private static func archive(
        _ ledger: ScreenTimeTicketLedger,
        to historyStore: ScreenTimeUsageHistoryStore
    ) {
        let record = ScreenTimeDayRecord(ledger: ledger)
        do {
            try historyStore.update { history in
                history.upsert(record)
            }
            logger.notice("Archived Screen Time day \(record.dayOrdinal, privacy: .public)")
        } catch {
            // ここで失敗するとその日の実績は復元できない。握り潰さずに記録を残す。
            logger.error(
                """
                Failed to archive Screen Time day \(record.dayOrdinal, privacy: .public): \
                \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    // MARK: - チケット

    @discardableResult
    func startTicket(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ScreenTimeTicketLedger {
        let settings = ScreenTimeFocusShared.loadSettings()
        guard settings.isEnabled, settings.ticketsEnabled else {
            throw ScreenTimeTicketStartError.ticketsDisabled
        }
        guard let nextDayStart = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: referenceDate)
        ) else {
            throw ScreenTimeTicketStartError.midnightCalculationFailed
        }
        // 期限監視のスケジュールは分粒度でしか境界を持てないため、台帳側の期限も分境界へ
        // 切り上げて一致させる。ズレたままだと期限コールバック時点で `hasActiveTicket` が
        // まだ true になり、再シールドではなく制限解除が走ってしまう。
        let nominalExpiry = ScreenTimeDateMath.ceilingToMinute(
            referenceDate.addingTimeInterval(
                TimeInterval(ScreenTimeFocusSettings.ticketDurationMinutes * 60)
            ),
            calendar: calendar
        )
        let expiry = min(nominalExpiry, nextDayStart)
        let progress = ScreenTimeFocusShared.loadDailyGoalProgress()
        let runtime = ScreenTimeFocusShared.loadRuntimeState()
        let locationPresence = ScreenTimeFocusShared.isLocationMonitoringArmed
            ? ScreenTimeFocusShared.loadLocationPresence()
            : ScreenTimeLocationPresence()

        let reservation: (previous: ScreenTimeTicketLedger, reserved: ScreenTimeTicketLedger) =
            try ledgerStore.update(
                settings: settings,
                referenceDate: referenceDate,
                calendar: calendar
            ) { ledger in
                let decision = ScreenTimePolicyEvaluator.evaluate(
                    settings: settings,
                    ledger: ledger,
                    dailyGoalProgress: progress,
                    runtimeState: runtime,
                    locationPresence: locationPresence,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
                if ledger.hasActiveTicket(at: referenceDate, calendar: calendar) {
                    throw ScreenTimeTicketStartError.activeTicket
                }
                guard decision.restrictsAllApps else {
                    // 持ち時間の使い切りはチケットでは開けられない（別資源）。
                    throw ScreenTimeTicketStartError.alreadyUnrestricted
                }
                guard decision.isTicketBypassable else {
                    throw ScreenTimeTicketStartError.nonNegotiable
                }

                let previous = ledger
                do {
                    try ledger.reserveTicket(
                        start: referenceDate,
                        expiry: expiry,
                        settings: settings,
                        calendar: calendar
                    )
                } catch ScreenTimeTicketLedgerMutationError.activeTicket {
                    throw ScreenTimeTicketStartError.activeTicket
                } catch ScreenTimeTicketLedgerMutationError.noTicketsRemaining {
                    throw ScreenTimeTicketStartError.noTicketsRemaining
                } catch ScreenTimeTicketLedgerMutationError.notCurrentDay {
                    throw ScreenTimeTicketStartError.noTicketsRemaining
                } catch ScreenTimeTicketLedgerMutationError.cooldown(let until) {
                    throw ScreenTimeTicketStartError.cooldown(until: until)
                }
                return (previous: previous, reserved: ledger)
            }

        do {
            try registerTicketExpiryMonitoring(expiry: expiry, calendar: calendar)
            _ = try applyCurrentPolicy(referenceDate: referenceDate, calendar: calendar)
            Self.logger.notice("Screen Time ticket started")
            return reservation.reserved
        } catch {
            try? ledgerStore.rollbackReservation(
                to: reservation.previous,
                reserved: reservation.reserved,
                settings: settings,
                referenceDate: referenceDate,
                calendar: calendar
            )
            stopTicketExpiryMonitoring()
            _ = try? applyCurrentPolicy(referenceDate: referenceDate, calendar: calendar)
            Self.logger.error("Screen Time ticket monitoring failed: \(error.localizedDescription, privacy: .public)")
            if error is ScreenTimeFocusError {
                throw error
            }
            throw ScreenTimeTicketStartError.monitoringFailed
        }
    }

    func stopAllMonitoringAndClearRestrictions() {
        let activityNames = deviceActivityCenter.activities.filter {
            $0.rawValue.hasPrefix(ScreenTimeFocusShared.scheduleActivityNamePrefix)
                || $0 == ScreenTimeFocusShared.dailyBoundaryActivityName
                || $0 == ScreenTimeFocusShared.ticketExpiryActivityName
                || $0 == ScreenTimeFocusShared.timerExpiryActivityName
                || $0 == ScreenTimeFocusShared.budgetActivityName
        }
        if !activityNames.isEmpty {
            deviceActivityCenter.stopMonitoring(activityNames)
        }
        ScreenTimeFocusShared.setBudgetMonitoringFingerprint(nil)
        ScreenTimeFocusShared.setBudgetLadderCeilingMinutes(nil)
        ScreenTimeFocusShared.clearRestrictions(using: policyStore)
        ScreenTimeFocusShared.clearRestrictions(using: budgetStore)
        clearLegacyStores()
    }

    /// 期限監視コールバックを受けて、使用中チケットを台帳上でも終了させる。
    ///
    /// これを行わないと再シールドの可否が `hasActiveTicket` の壁時計比較だけに依存し、
    /// コールバックの配送タイミング次第で「まだ有効」と判定されて制限が戻らない。
    /// 期限に達していないチケットは触らない（誤配送でチケットを失わせないため）。
    @discardableResult
    func finalizeExpiredTicket(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        let settings = ScreenTimeFocusShared.loadSettings()
        guard try ledgerStore.load(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar,
            createIfMissing: false
        ) != nil else {
            return false
        }
        return try ledgerStore.update(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        ) { ledger in
            guard let endsAt = ledger.activeTicketEndsAt,
                  endsAt <= ScreenTimeDateMath.epochMilliseconds(for: referenceDate) else {
                return false
            }
            ledger.endActiveTicket()
            return true
        }
    }

    func completeOneShotMonitoring(_ activity: DeviceActivityName) {
        guard activity == ScreenTimeFocusShared.ticketExpiryActivityName
                || activity == ScreenTimeFocusShared.timerExpiryActivityName else {
            return
        }
        if deviceActivityCenter.activities.contains(activity) {
            deviceActivityCenter.stopMonitoring([activity])
        }
    }

    // MARK: - 通知

    /// 持ち時間の残りが少なくなった／尽きたことを知らせる。
    ///
    /// 使いすぎ防止では「気づき」が壁と同じくらい効く。壁に当たって初めて知る状態を避ける。
    func notifyUsage(outcome: ScreenTimeUsageMilestoneOutcome) {
        let content = UNMutableNotificationContent()
        if outcome.shouldNotifyExhausted {
            content.title = "今日の持ち時間を使い切りました"
            content.body = "対象のアプリは明日まで開けません。勉強すると持ち時間が増えます。"
        } else if outcome.shouldNotifyWarning {
            content.title = "持ち時間があと\(outcome.remainingMinutes)分"
            content.body = "使い切ると対象のアプリが開けなくなります。"
        } else {
            return
        }
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: "screen-time-usage-\(outcome.shouldNotifyExhausted ? "exhausted" : "warning")-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        // 呼び出し元は `DeviceActivityMonitor` 拡張で、実行予算を使い切ると即座に
        // サスペンドされる。登録完了を待たずに戻ると通知が消えるが、台帳側の
        // 通知済みフラグは既に立っているため再送もされない。短く待って取りこぼしを防ぐ。
        let completion = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error(
                    "Failed to post usage notification: \(error.localizedDescription, privacy: .public)"
                )
            }
            completion.signal()
        }
        if completion.wait(timeout: .now() + 2) == .timedOut {
            Self.logger.error("Timed out while enqueueing usage notification")
        }
    }

    // MARK: - 内部

    private static func requiresLedger(_ settings: ScreenTimeFocusSettings) -> Bool {
        settings.ticketsEnabled || settings.goalRestrictionEnabled
    }

    /// 台帳を必要としない設定のときは、共有ファイルにも触らない。
    /// 触ると App Group が使えない環境（未署名ビルドなど）で毎回失敗し、
    /// 制限を何も使っていないのにエラーとして表面化してしまう。
    private func currentLedger(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar,
        createIfMissing: Bool
    ) throws -> ScreenTimeTicketLedger? {
        guard createIfMissing || Self.requiresLedger(settings) else { return nil }
        return try ledgerStore.load(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar,
            createIfMissing: createIfMissing
        )
    }

    private func cancelActiveTicketIfPresent(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar
    ) throws {
        guard try ledgerStore.load(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar,
            createIfMissing: false
        ) != nil else {
            return
        }
        try ledgerStore.update(
            settings: settings,
            referenceDate: referenceDate,
            calendar: calendar
        ) { ledger in
            ledger.endActiveTicket()
        }
    }

    private func registerDailyBoundaryMonitoring() throws {
        guard !deviceActivityCenter.activities.contains(ScreenTimeFocusShared.dailyBoundaryActivityName) else {
            return
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try deviceActivityCenter.startMonitoring(
            ScreenTimeFocusShared.dailyBoundaryActivityName,
            during: schedule
        )
    }

    /// 期限を「ウィンドウの開始」に置いた一回限りのスケジュールを作る。
    ///
    /// 期限をウィンドウの終端にすると、登録時点でウィンドウがすでに進行中になるうえ、
    /// 分粒度への丸めで `intervalDidEnd` が実際の期限より前に届きうる。その場合
    /// 再評価はまだ「チケット有効」と判定し、再シールドではなく制限解除が走ってしまう。
    /// 期限を開始側に置けば未来から始まるウィンドウになり、システムは期限より前に発火しない。
    /// 終端の +15 分は `DeviceActivitySchedule` の最小長を満たすためだけのもの。
    private static func expirySchedule(expiry: Date, calendar: Calendar) -> DeviceActivitySchedule {
        let components: Set<Calendar.Component> = [
            .era, .year, .month, .day, .hour, .minute
        ]
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: expiry),
            intervalEnd: calendar.dateComponents(
                components,
                from: expiry.addingTimeInterval(15 * 60)
            ),
            repeats: false
        )
    }

    private func registerTicketExpiryMonitoring(expiry: Date, calendar: Calendar) throws {
        stopTicketExpiryMonitoring()
        try deviceActivityCenter.startMonitoring(
            ScreenTimeFocusShared.ticketExpiryActivityName,
            during: Self.expirySchedule(expiry: expiry, calendar: calendar)
        )
    }

    private func registerTimerExpiryMonitoring(expiry: Date, calendar: Calendar) throws {
        stopTimerExpiryMonitoring()
        try deviceActivityCenter.startMonitoring(
            ScreenTimeFocusShared.timerExpiryActivityName,
            during: Self.expirySchedule(expiry: expiry, calendar: calendar)
        )
    }

    private func stopScheduleMonitoring() {
        let names = deviceActivityCenter.activities.filter {
            $0.rawValue.hasPrefix(ScreenTimeFocusShared.scheduleActivityNamePrefix)
        }
        if !names.isEmpty {
            deviceActivityCenter.stopMonitoring(names)
        }
    }

    private func stopDailyBoundaryMonitoring() {
        if deviceActivityCenter.activities.contains(ScreenTimeFocusShared.dailyBoundaryActivityName) {
            deviceActivityCenter.stopMonitoring([ScreenTimeFocusShared.dailyBoundaryActivityName])
        }
    }

    private func stopTicketExpiryMonitoring() {
        if deviceActivityCenter.activities.contains(ScreenTimeFocusShared.ticketExpiryActivityName) {
            deviceActivityCenter.stopMonitoring([ScreenTimeFocusShared.ticketExpiryActivityName])
        }
    }

    private func stopTimerExpiryMonitoring() {
        if deviceActivityCenter.activities.contains(ScreenTimeFocusShared.timerExpiryActivityName) {
            deviceActivityCenter.stopMonitoring([ScreenTimeFocusShared.timerExpiryActivityName])
        }
    }

    private func stopBudgetMonitoring() {
        if deviceActivityCenter.activities.contains(ScreenTimeFocusShared.budgetActivityName) {
            deviceActivityCenter.stopMonitoring([ScreenTimeFocusShared.budgetActivityName])
        }
    }

    private func clearLegacyStores() {
        ScreenTimeFocusShared.clearRestrictions(using: legacyTimerStore)
        ScreenTimeFocusShared.clearRestrictions(using: legacyScheduleStore)
    }
}
