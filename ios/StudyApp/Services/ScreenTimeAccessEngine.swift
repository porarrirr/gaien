import DeviceActivity
import Foundation
import ManagedSettings
import OSLog

enum ScreenTimeFocusError: LocalizedError {
    case unavailable
    case authorizationRequired
    case missingAllowedApplications
    case settingsSaveFailed
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
        case .missingAllowedApplications:
            return "許可するアプリを選択してください"
        case .settingsSaveFailed:
            return "集中制限の設定を保存できませんでした"
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
}

enum ScreenTimeTicketStartError: LocalizedError, Equatable {
    case ticketsDisabled
    case alreadyUnrestricted
    case activeTicket
    case noTicketsRemaining
    case midnightCalculationFailed
    case monitoringFailed

    var errorDescription: String? {
        switch self {
        case .ticketsDisabled:
            return "チケット制が有効ではありません"
        case .alreadyUnrestricted:
            return "現在はチケットなしで利用できます"
        case .activeTicket:
            return "使用中のチケットが終了してから次のチケットを使ってください"
        case .noTicketsRemaining:
            return "今日使えるチケットは残っていません"
        case .midnightCalculationFailed:
            return "チケットの終了時刻を計算できませんでした"
        case .monitoringFailed:
            return "チケットの終了監視を開始できませんでした"
        }
    }
}

struct ScreenTimeAccessEngine {
    private static let logger = Logger(
        subsystem: "com.studyapp.ios",
        category: "ScreenTimeAccess"
    )

    private let ledgerStore: ScreenTimeTicketLedgerStore
    private let deviceActivityCenter: DeviceActivityCenter
    private let policyStore: ManagedSettingsStore
    private let legacyTimerStore: ManagedSettingsStore
    private let legacyScheduleStore: ManagedSettingsStore

    init(
        ledgerStore: ScreenTimeTicketLedgerStore = ScreenTimeTicketLedgerStore(),
        deviceActivityCenter: DeviceActivityCenter = DeviceActivityCenter()
    ) {
        self.ledgerStore = ledgerStore
        self.deviceActivityCenter = deviceActivityCenter
        self.policyStore = ManagedSettingsStore(named: ScreenTimeFocusShared.policyStoreName)
        self.legacyTimerStore = ManagedSettingsStore(named: ScreenTimeFocusShared.legacyTimerStoreName)
        self.legacyScheduleStore = ManagedSettingsStore(named: ScreenTimeFocusShared.legacyScheduleStoreName)
    }

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
            createIfMissing: settings.ticketRestrictionEnabled
        )
        let decision = ScreenTimePolicyEvaluator.evaluate(
            settings: settings,
            ledger: ledger,
            dailyGoalProgress: ScreenTimeFocusShared.loadDailyGoalProgress(),
            runtimeState: ScreenTimeFocusShared.loadRuntimeState(),
            referenceDate: referenceDate,
            calendar: calendar
        )
        return ScreenTimeAccessSnapshot(
            ledger: ledger,
            decision: decision,
            nextAllowedScheduleStart: settings.nextAllowedScheduleStart(
                after: referenceDate,
                calendar: calendar
            )
        )
    }

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

        if snapshot.decision.isRestricted {
            let result = ScreenTimeFocusShared.applyRestrictions(
                using: policyStore,
                settings: settings
            )
            if result == .missingAllowedSelection {
                throw ScreenTimeFocusError.missingAllowedApplications
            }
        } else {
            ScreenTimeFocusShared.clearRestrictions(using: policyStore)
        }
        return snapshot.decision
    }

    func syncMonitoring(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        try settings.validateMonitoringConfiguration()
        guard !settings.requiresAllowedSelection || settings.canApplyRestrictions else {
            throw ScreenTimeFocusError.missingAllowedApplications
        }
        clearLegacyStores()
        stopScheduleMonitoring()

        guard settings.isEnabled else {
            stopDailyBoundaryMonitoring()
            stopTicketExpiryMonitoring()
            stopTimerExpiryMonitoring()
            ScreenTimeFocusShared.clearRestrictions(using: policyStore)
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

        if settings.ticketRestrictionEnabled {
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
            if !settings.ticketRestrictionEnabled {
                try cancelActiveTicketIfPresent(
                    settings: settings,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
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
              !settings.unlockRestrictionsWhenDailyGoalReached,
              settings.timerRestrictionEnabled,
              runtimeState.isTimerRestrictionActive(at: referenceDate),
              let expiry = runtimeState.timerRestrictionEndDate else {
            return
        }
        try registerTimerExpiryMonitoring(expiry: expiry, calendar: calendar)
    }

    @discardableResult
    func startTicket(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ScreenTimeTicketLedger {
        let settings = ScreenTimeFocusShared.loadSettings()
        guard settings.isEnabled, settings.ticketRestrictionEnabled else {
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
                    referenceDate: referenceDate,
                    calendar: calendar
                )
                if ledger.hasActiveTicket(at: referenceDate, calendar: calendar) {
                    throw ScreenTimeTicketStartError.activeTicket
                }
                switch decision.reason {
                case .dailyGoalPending, .studyTimer, .blockedSchedule, .ticketRequired:
                    break
                case .dailyGoalReached, .allowedSchedule, .masterDisabled, .unrestricted:
                    throw ScreenTimeTicketStartError.alreadyUnrestricted
                case .activeTicket:
                    throw ScreenTimeTicketStartError.activeTicket
                case .outsideScheduleBlocked:
                    throw ScreenTimeTicketStartError.ticketsDisabled
                }

                let previous = ledger
                do {
                    try ledger.reserveTicket(start: referenceDate, expiry: expiry, calendar: calendar)
                } catch ScreenTimeTicketLedgerMutationError.activeTicket {
                    throw ScreenTimeTicketStartError.activeTicket
                } catch ScreenTimeTicketLedgerMutationError.noTicketsRemaining {
                    throw ScreenTimeTicketStartError.noTicketsRemaining
                } catch ScreenTimeTicketLedgerMutationError.notCurrentDay {
                    throw ScreenTimeTicketStartError.noTicketsRemaining
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
        }
        if !activityNames.isEmpty {
            deviceActivityCenter.stopMonitoring(activityNames)
        }
        ScreenTimeFocusShared.clearRestrictions(using: policyStore)
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

    private func currentLedger(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar,
        createIfMissing: Bool
    ) throws -> ScreenTimeTicketLedger? {
        guard settings.ticketRestrictionEnabled || createIfMissing else { return nil }
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
            ledger.activeTicketStartedAt = nil
            ledger.activeTicketEndsAt = nil
        }
    }

    private func registerDailyBoundaryMonitoring() throws {
        stopDailyBoundaryMonitoring()
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

    private func clearLegacyStores() {
        ScreenTimeFocusShared.clearRestrictions(using: legacyTimerStore)
        ScreenTimeFocusShared.clearRestrictions(using: legacyScheduleStore)
    }
}
