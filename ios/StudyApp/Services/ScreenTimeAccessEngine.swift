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
        let settings = ScreenTimeFocusShared.loadSettings()
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
        let settings = ScreenTimeFocusShared.loadSettings()
        let snapshot = try snapshot(referenceDate: referenceDate, calendar: calendar)

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
        let nominalExpiry = referenceDate.addingTimeInterval(
            TimeInterval(ScreenTimeFocusSettings.ticketDurationMinutes * 60)
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

    private func registerTicketExpiryMonitoring(expiry: Date, calendar: Calendar) throws {
        let start = expiry.addingTimeInterval(-15 * 60)
        let components: Set<Calendar.Component> = [
            .era, .year, .month, .day, .hour, .minute, .second
        ]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start),
            intervalEnd: calendar.dateComponents(components, from: expiry),
            repeats: false
        )
        try deviceActivityCenter.startMonitoring(
            ScreenTimeFocusShared.ticketExpiryActivityName,
            during: schedule
        )
    }

    private func registerTimerExpiryMonitoring(expiry: Date, calendar: Calendar) throws {
        let start = expiry.addingTimeInterval(-15 * 60)
        let components: Set<Calendar.Component> = [
            .era, .year, .month, .day, .hour, .minute, .second
        ]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start),
            intervalEnd: calendar.dateComponents(components, from: expiry),
            repeats: false
        )
        try deviceActivityCenter.startMonitoring(
            ScreenTimeFocusShared.timerExpiryActivityName,
            during: schedule
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
