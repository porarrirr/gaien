import Foundation

enum ScreenTimeTicketLedgerMutationError: Error, Equatable {
    case activeTicket
    case noTicketsRemaining
    case notCurrentDay
    case cooldown(until: Date)
}

/// 1日分の台帳。
///
/// 2つの資源を持つ。
/// - **持ち時間**（分）: 対象アプリを実際に使える総量。基本枠＋勉強で稼いだ分＋目標達成ボーナスで
///   増え、対象アプリの実使用（`usageMilestoneMinutes`）で減る。
/// - **チケット**（枚）: 交渉可能な壁を10分だけ開ける鍵。持ち時間は消費しない。
///
/// 実使用は Screen Time から直接読めないため、`DeviceActivityEvent` のしきい値到達で
/// 判明した「到達済みの最大段」を下限として記録する。したがって `usageMilestoneMinutes` は
/// 常に実際の使用時間以下であり、段の間隔ぶんの誤差を持つ。
struct ScreenTimeTicketLedger: Codable, Equatable {
    var dayStart: Int64
    /// Gregorian-style local date ordinal (yyyyMMdd) used to prevent reissuing
    /// tickets when the device clock or time zone moves backwards.
    var issuedLocalDayOrdinal: Int?

    // 持ち時間
    var baseAllowanceMinutes: Int
    var earnedAllowanceMinutes: Int
    var bonusAllowanceMinutes: Int
    /// しきい値到達で判明した実使用の下限（分）。
    var usageMilestoneMinutes: Int
    /// 監視を貼り直した時点までに記録済みだった使用量。
    ///
    /// `startMonitoring` を貼り直すとしきい値の起点が 0 に戻るため、以降のしきい値到達は
    /// 「貼り直し後の使用量」を表す。この値を足してから記録することで、対象アプリを
    /// 選び直して使用量を巻き戻す抜け道を防ぐ。
    var usageBaselineMinutes: Int

    // チケット
    var issuedTicketCount: Int
    var usedTicketCount: Int
    var activeTicketStartedAt: Int64?
    var activeTicketEndsAt: Int64?
    var lastTicketEndedAt: Int64?

    // 記録（日次レポート用）
    var shieldInteractionCount: Int
    var studyMinutes: Int
    var goalTargetMinutes: Int
    /// 制限がオンのままScreen Timeの許可が外れた日を残す。
    var protectionInterrupted: Bool
    var notifiedUsageWarning: Bool
    var notifiedUsageExhausted: Bool

    var updatedAt: Int64

    init(
        dayStart: Int64,
        issuedLocalDayOrdinal: Int? = nil,
        baseAllowanceMinutes: Int = 0,
        earnedAllowanceMinutes: Int = 0,
        bonusAllowanceMinutes: Int = 0,
        usageMilestoneMinutes: Int = 0,
        usageBaselineMinutes: Int = 0,
        issuedTicketCount: Int = 0,
        usedTicketCount: Int = 0,
        activeTicketStartedAt: Int64? = nil,
        activeTicketEndsAt: Int64? = nil,
        lastTicketEndedAt: Int64? = nil,
        shieldInteractionCount: Int = 0,
        studyMinutes: Int = 0,
        goalTargetMinutes: Int = 0,
        protectionInterrupted: Bool = false,
        notifiedUsageWarning: Bool = false,
        notifiedUsageExhausted: Bool = false,
        updatedAt: Int64 = 0
    ) {
        self.dayStart = dayStart
        self.issuedLocalDayOrdinal = issuedLocalDayOrdinal
        self.baseAllowanceMinutes = baseAllowanceMinutes
        self.earnedAllowanceMinutes = earnedAllowanceMinutes
        self.bonusAllowanceMinutes = bonusAllowanceMinutes
        self.usageMilestoneMinutes = usageMilestoneMinutes
        self.usageBaselineMinutes = usageBaselineMinutes
        self.issuedTicketCount = issuedTicketCount
        self.usedTicketCount = usedTicketCount
        self.activeTicketStartedAt = activeTicketStartedAt
        self.activeTicketEndsAt = activeTicketEndsAt
        self.lastTicketEndedAt = lastTicketEndedAt
        self.shieldInteractionCount = shieldInteractionCount
        self.studyMinutes = studyMinutes
        self.goalTargetMinutes = goalTargetMinutes
        self.protectionInterrupted = protectionInterrupted
        self.notifiedUsageWarning = notifiedUsageWarning
        self.notifiedUsageExhausted = notifiedUsageExhausted
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case dayStart
        case issuedLocalDayOrdinal
        case baseAllowanceMinutes
        case earnedAllowanceMinutes
        case bonusAllowanceMinutes
        case usageMilestoneMinutes
        case usageBaselineMinutes
        case issuedTicketCount
        case usedTicketCount
        case activeTicketStartedAt
        case activeTicketEndsAt
        case lastTicketEndedAt
        case shieldInteractionCount
        case studyMinutes
        case goalTargetMinutes
        case protectionInterrupted
        case notifiedUsageWarning
        case notifiedUsageExhausted
        case updatedAt
    }

    /// 旧スキーマ（持ち時間の概念が無かった頃）のファイルも読めるようにする。
    /// 欠けている値は 0 で始まり、その日の `normalize` で設定から付与される。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayStart = try container.decode(Int64.self, forKey: .dayStart)
        issuedLocalDayOrdinal = try container.decodeIfPresent(Int.self, forKey: .issuedLocalDayOrdinal)
        baseAllowanceMinutes = try container.decodeIfPresent(Int.self, forKey: .baseAllowanceMinutes) ?? 0
        earnedAllowanceMinutes = try container.decodeIfPresent(Int.self, forKey: .earnedAllowanceMinutes) ?? 0
        bonusAllowanceMinutes = try container.decodeIfPresent(Int.self, forKey: .bonusAllowanceMinutes) ?? 0
        usageMilestoneMinutes = try container.decodeIfPresent(Int.self, forKey: .usageMilestoneMinutes) ?? 0
        usageBaselineMinutes = try container.decodeIfPresent(Int.self, forKey: .usageBaselineMinutes) ?? 0
        issuedTicketCount = try container.decodeIfPresent(Int.self, forKey: .issuedTicketCount) ?? 0
        usedTicketCount = try container.decodeIfPresent(Int.self, forKey: .usedTicketCount) ?? 0
        activeTicketStartedAt = try container.decodeIfPresent(Int64.self, forKey: .activeTicketStartedAt)
        activeTicketEndsAt = try container.decodeIfPresent(Int64.self, forKey: .activeTicketEndsAt)
        lastTicketEndedAt = try container.decodeIfPresent(Int64.self, forKey: .lastTicketEndedAt)
        shieldInteractionCount = try container.decodeIfPresent(Int.self, forKey: .shieldInteractionCount) ?? 0
        studyMinutes = try container.decodeIfPresent(Int.self, forKey: .studyMinutes) ?? 0
        goalTargetMinutes = try container.decodeIfPresent(Int.self, forKey: .goalTargetMinutes) ?? 0
        protectionInterrupted = try container.decodeIfPresent(Bool.self, forKey: .protectionInterrupted) ?? false
        notifiedUsageWarning = try container.decodeIfPresent(Bool.self, forKey: .notifiedUsageWarning) ?? false
        notifiedUsageExhausted = try container.decodeIfPresent(Bool.self, forKey: .notifiedUsageExhausted) ?? false
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
    }

    static func make(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> ScreenTimeTicketLedger {
        ScreenTimeTicketLedger(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: referenceDate)),
            issuedLocalDayOrdinal: ScreenTimeDateMath.localDayOrdinal(for: referenceDate, calendar: calendar),
            baseAllowanceMinutes: settings.baseAllowanceMinutes,
            issuedTicketCount: settings.dailyTicketCount,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: referenceDate)
        )
    }

    // MARK: - 持ち時間

    var totalAllowanceMinutes: Int {
        max(baseAllowanceMinutes, 0) + max(earnedAllowanceMinutes, 0) + max(bonusAllowanceMinutes, 0)
    }

    var remainingAllowanceMinutes: Int {
        max(totalAllowanceMinutes - max(usageMilestoneMinutes, 0), 0)
    }

    var allowanceProgressRatio: Double {
        guard totalAllowanceMinutes > 0 else { return 1 }
        return min(Double(max(usageMilestoneMinutes, 0)) / Double(totalAllowanceMinutes), 1)
    }

    func isBudgetExhausted(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isForDay(containing: date, calendar: calendar) else { return false }
        return usageMilestoneMinutes >= totalAllowanceMinutes
    }

    /// しきい値到達を取り込む。段は到達順に届く保証がないため、最大値だけを保つ。
    /// 監視の貼り直しをまたいでも巻き戻らないよう、ベースラインを足してから比較する。
    /// - Returns: 記録が進んだかどうか。
    @discardableResult
    mutating func recordUsageMilestone(minutes: Int) -> Bool {
        let absolute = max(usageBaselineMinutes, 0) + max(minutes, 0)
        guard absolute > usageMilestoneMinutes else { return false }
        usageMilestoneMinutes = absolute
        return true
    }

    /// 使用量監視を貼り直した直後に呼ぶ。以降のしきい値到達は 0 から数え直されるため、
    /// ここまでの記録をベースラインとして固定する。
    mutating func markUsageMonitoringRestarted() {
        usageBaselineMinutes = max(usageMilestoneMinutes, 0)
    }

    /// 台帳が属するローカル日付序数（yyyyMMdd）。
    func localDayOrdinal(calendar: Calendar = .current) -> Int {
        effectiveIssuedLocalDayOrdinal(calendar: calendar)
    }

    // MARK: - チケット

    var remainingTicketCount: Int {
        max(issuedTicketCount - usedTicketCount, 0)
    }

    var activeTicketEndDate: Date? {
        guard let activeTicketEndsAt else { return nil }
        return ScreenTimeDateMath.date(fromEpochMilliseconds: activeTicketEndsAt)
    }

    /// 次のチケットまで待つ分数。使うほど長くなる。
    func cooldownMinutes(settings: ScreenTimeFocusSettings) -> Int {
        guard usedTicketCount > 0 else { return 0 }
        let escalation = max(settings.ticketCooldownEscalationMinutes, 0) * max(usedTicketCount - 1, 0)
        return max(settings.ticketCooldownMinutes, 0) + escalation
    }

    func ticketCooldownEndDate(settings: ScreenTimeFocusSettings) -> Date? {
        guard let lastTicketEndedAt else { return nil }
        let minutes = cooldownMinutes(settings: settings)
        guard minutes > 0 else { return nil }
        return ScreenTimeDateMath.date(fromEpochMilliseconds: lastTicketEndedAt)
            .addingTimeInterval(TimeInterval(minutes * 60))
    }

    func isInTicketCooldown(at date: Date, settings: ScreenTimeFocusSettings) -> Bool {
        guard let end = ticketCooldownEndDate(settings: settings) else { return false }
        return date < end
    }

    /// 次にチケットを使えるようになる時刻。使用中なら終了時刻、待機中なら待機終了時刻。
    func nextTicketAvailableDate(at date: Date, settings: ScreenTimeFocusSettings) -> Date? {
        if hasActiveTicket(at: date), let end = activeTicketEndDate {
            // 使用中のチケットは `usedTicketCount` に含まれているため、
            // 終了後に適用される待機時間は現在値のまま計算できる。
            return end.addingTimeInterval(TimeInterval(cooldownMinutes(settings: settings) * 60))
        }
        guard let cooldownEnd = ticketCooldownEndDate(settings: settings), date < cooldownEnd else {
            return nil
        }
        return cooldownEnd
    }

    func isForDay(containing date: Date, calendar: Calendar = .current) -> Bool {
        effectiveIssuedLocalDayOrdinal(calendar: calendar)
            == ScreenTimeDateMath.localDayOrdinal(for: date, calendar: calendar)
    }

    func hasActiveTicket(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isForDay(containing: date, calendar: calendar),
              let activeTicketEndsAt else {
            return false
        }
        return ScreenTimeDateMath.epochMilliseconds(for: date) < activeTicketEndsAt
    }

    /// その日まだ何も消費していない間は、枚数と持ち時間の変更をそのまま反映できる
    /// （設定直後の調整に相当する）。消費が始まったあとは減らす変更だけを反映する。
    func canGrantFreely(at date: Date, calendar: Calendar = .current) -> Bool {
        isForDay(containing: date, calendar: calendar)
            && usedTicketCount == 0
            && usageMilestoneMinutes == 0
    }

    mutating func reserveTicket(
        start: Date,
        expiry: Date,
        settings: ScreenTimeFocusSettings,
        calendar: Calendar = .current
    ) throws {
        guard isForDay(containing: start, calendar: calendar) else {
            throw ScreenTimeTicketLedgerMutationError.notCurrentDay
        }
        guard !hasActiveTicket(at: start, calendar: calendar) else {
            throw ScreenTimeTicketLedgerMutationError.activeTicket
        }
        guard remainingTicketCount > 0 else {
            throw ScreenTimeTicketLedgerMutationError.noTicketsRemaining
        }
        if let cooldownEnd = ticketCooldownEndDate(settings: settings), start < cooldownEnd {
            throw ScreenTimeTicketLedgerMutationError.cooldown(until: cooldownEnd)
        }
        usedTicketCount += 1
        activeTicketStartedAt = ScreenTimeDateMath.epochMilliseconds(for: start)
        activeTicketEndsAt = ScreenTimeDateMath.epochMilliseconds(for: expiry)
        updatedAt = ScreenTimeDateMath.epochMilliseconds(for: start)
    }

    /// 使用中チケットの区間だけを終了させる。消費済み枚数は戻さない。
    /// 終了時刻を残し、次のチケットまでの待機の起点にする。
    mutating func endActiveTicket() {
        if let activeTicketEndsAt {
            lastTicketEndedAt = max(lastTicketEndedAt ?? activeTicketEndsAt, activeTicketEndsAt)
        }
        activeTicketStartedAt = nil
        activeTicketEndsAt = nil
    }

    mutating func normalize(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar = .current
    ) {
        let currentDayOrdinal = ScreenTimeDateMath.localDayOrdinal(for: referenceDate, calendar: calendar)
        if currentDayOrdinal > effectiveIssuedLocalDayOrdinal(calendar: calendar) {
            self = Self.make(settings: settings, referenceDate: referenceDate, calendar: calendar)
            return
        }
        if issuedLocalDayOrdinal == nil {
            issuedLocalDayOrdinal = effectiveIssuedLocalDayOrdinal(calendar: calendar)
        }
        applyGrantChanges(settings: settings, referenceDate: referenceDate, calendar: calendar)
        if !isForDay(containing: referenceDate, calendar: calendar)
            || !hasActiveTicket(at: referenceDate, calendar: calendar) {
            endActiveTicket()
        }
        updatedAt = ScreenTimeDateMath.epochMilliseconds(for: referenceDate)
    }

    /// 設定変更をその日の付与へ反映する。
    ///
    /// 消費が始まる前は自由に反映する。始まったあとは「減らす変更だけ即時、
    /// 増やす変更は翌日から」というラチェットにする。壁に当たってから枠を増やして
    /// 抜けられる状態にしないため。
    private mutating func applyGrantChanges(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar
    ) {
        if canGrantFreely(at: referenceDate, calendar: calendar) {
            baseAllowanceMinutes = settings.baseAllowanceMinutes
            issuedTicketCount = settings.dailyTicketCount
        } else {
            baseAllowanceMinutes = min(baseAllowanceMinutes, settings.baseAllowanceMinutes)
            issuedTicketCount = min(issuedTicketCount, settings.dailyTicketCount)
        }
        // 稼いだ分とボーナスは学習実績から毎回計算し直すため、上限の縮小も即時に効く。
        let cap = settings.earnedAllowanceEnabled ? max(settings.earnedAllowanceCapMinutes, 0) : 0
        earnedAllowanceMinutes = min(earnedAllowanceMinutes, cap)
        bonusAllowanceMinutes = min(bonusAllowanceMinutes, max(settings.goalBonusAllowanceMinutes, 0))
    }

    /// 学習実績にもとづく付与を書き込む。ホストアプリだけが呼ぶ。
    /// - Returns: 付与が増えたかどうか。
    @discardableResult
    mutating func applyStudyProgress(
        progress: ScreenTimeDailyGoalProgress,
        settings: ScreenTimeFocusSettings,
        goalReached: Bool
    ) -> Bool {
        let previousTotal = totalAllowanceMinutes
        studyMinutes = max(progress.studyMinutes, 0)
        goalTargetMinutes = max(progress.targetMinutes, 0)
        earnedAllowanceMinutes = ScreenTimeAllowance.earnedMinutes(
            studyMinutes: studyMinutes,
            settings: settings
        )
        bonusAllowanceMinutes = ScreenTimeAllowance.bonusMinutes(
            goalReached: goalReached,
            settings: settings
        )
        if totalAllowanceMinutes > previousTotal {
            // 枠が増えたら、使い切りの通知はまた出せるようにする。
            notifiedUsageExhausted = false
            notifiedUsageWarning = false
            return true
        }
        return false
    }

    private func effectiveIssuedLocalDayOrdinal(calendar: Calendar) -> Int {
        issuedLocalDayOrdinal
            ?? ScreenTimeDateMath.localDayOrdinal(
                for: ScreenTimeDateMath.date(fromEpochMilliseconds: dayStart),
                calendar: calendar
            )
    }
}

enum ScreenTimeTicketLedgerStoreError: LocalizedError {
    case appGroupUnavailable
    case coordinationFailed
    case stateReadFailed
    case stateWriteFailed

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "チケットの共有保存領域を利用できません"
        case .coordinationFailed:
            return "チケット状態を安全に更新できませんでした"
        case .stateReadFailed:
            return "チケット状態を読み込めませんでした"
        case .stateWriteFailed:
            return "チケット状態を保存できませんでした"
        }
    }
}

struct ScreenTimeTicketLedgerStore {
    typealias FileURLProvider = () -> URL?
    /// 日付が変わった台帳を捨てる直前に、その内容を受け取るフック。
    typealias StaleDayHandler = (ScreenTimeTicketLedger) -> Void

    private let fileURLProvider: FileURLProvider
    private let staleDayHandler: StaleDayHandler?

    init(
        fileURLProvider: @escaping FileURLProvider = {
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: ScreenTimeFocusShared.appGroupIdentifier)?
                .appendingPathComponent("screen-time-ticket-ledger-v1.json", isDirectory: false)
        },
        onStaleDay staleDayHandler: StaleDayHandler? = nil
    ) {
        self.fileURLProvider = fileURLProvider
        self.staleDayHandler = staleDayHandler
    }

    /// 日跨ぎ検知フックを差し替えた複製を返す。
    ///
    /// `ScreenTimeAccessEngine` が履歴ストアと台帳ストアを結線するために使う。
    /// 台帳ストア自身は履歴の存在を知らないまま、切り出しの機会だけを提供する。
    func withStaleDayHandler(_ handler: @escaping StaleDayHandler) -> ScreenTimeTicketLedgerStore {
        ScreenTimeTicketLedgerStore(fileURLProvider: fileURLProvider, onStaleDay: handler)
    }

    func load(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        createIfMissing: Bool
    ) throws -> ScreenTimeTicketLedger? {
        try coordinate(settings: settings, referenceDate: referenceDate, calendar: calendar) { ledger in
            if ledger == nil, createIfMissing {
                ledger = ScreenTimeTicketLedger.make(
                    settings: settings,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
            return ledger
        }
    }

    /// 表示専用の読み取り。`NSFileCoordinator` を使わず、ファイルへも書き戻さない。
    ///
    /// `ShieldConfigurationDataSource` は極めて短い実行予算で同期的に応答する必要があり、
    /// ファイル協調の書き込みクレーム獲得も App Group への書き込みも前提にできない。
    /// `load(createIfMissing:)` はたとえ読み取り目的でも `coordinate(writingItemAt:)` を通り、
    /// `normalize()` の結果を毎回書き戻すため、この経路をシールド拡張から使うと
    /// 失敗が「残り0枚」として描画されてしまう。
    ///
    /// 協調なしで安全なのは `writeLedger` が `.atomic`（一時ファイル + rename）で書くため。
    /// 読み手は必ず新旧どちらかの完全なファイルを見る（破損した中間状態は観測されない）。
    func loadReadOnly(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ScreenTimeTicketLedger? {
        guard let fileURL = fileURLProvider() else {
            throw ScreenTimeTicketLedgerStoreError.appGroupUnavailable
        }
        guard var ledger = try readLedger(at: fileURL) else { return nil }
        ledger.normalize(settings: settings, referenceDate: referenceDate, calendar: calendar)
        return ledger
    }

    /// `normalize` を通さない生の読み取り。
    ///
    /// 日付をまたいだ台帳を履歴へ切り出すために使う。通常経路の読み取りは必ず
    /// 当日分へ正規化してしまうため、切り出す前の値がここでしか取れない。
    func loadRaw() throws -> ScreenTimeTicketLedger? {
        guard let fileURL = fileURLProvider() else {
            throw ScreenTimeTicketLedgerStoreError.appGroupUnavailable
        }
        return try readLedger(at: fileURL)
    }

    func update<T>(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        _ update: (inout ScreenTimeTicketLedger) throws -> T
    ) throws -> T {
        try coordinate(settings: settings, referenceDate: referenceDate, calendar: calendar) { ledger in
            if ledger == nil {
                ledger = ScreenTimeTicketLedger.make(
                    settings: settings,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
            guard var current = ledger else {
                throw ScreenTimeTicketLedgerStoreError.stateReadFailed
            }
            let result = try update(&current)
            current.updatedAt = ScreenTimeDateMath.epochMilliseconds(for: referenceDate)
            ledger = current
            return result
        }
    }

    func rollbackReservation(
        to previous: ScreenTimeTicketLedger,
        reserved: ScreenTimeTicketLedger,
        settings: ScreenTimeFocusSettings,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        try coordinate(settings: settings, referenceDate: referenceDate, calendar: calendar) { ledger in
            guard var current = ledger,
                  current.dayStart == reserved.dayStart,
                  current.activeTicketStartedAt == reserved.activeTicketStartedAt,
                  current.activeTicketEndsAt == reserved.activeTicketEndsAt,
                  current.usedTicketCount >= reserved.usedTicketCount else {
                return
            }
            current.usedTicketCount = max(current.usedTicketCount - 1, previous.usedTicketCount)
            current.activeTicketStartedAt = previous.activeTicketStartedAt
            current.activeTicketEndsAt = previous.activeTicketEndsAt
            current.lastTicketEndedAt = previous.lastTicketEndedAt
            ledger = current
        }
    }

    private func coordinate<T>(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar,
        _ operation: (inout ScreenTimeTicketLedger?) throws -> T
    ) throws -> T {
        guard let fileURL = fileURLProvider() else {
            throw ScreenTimeTicketLedgerStoreError.appGroupUnavailable
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationResult: Result<T, Error>?
        // 日付が変わって捨てられる台帳。協調ブロックを抜けてからフックへ渡す。
        var staleLedger: ScreenTimeTicketLedger?
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                var ledger = try readLedger(at: coordinatedURL)
                if var existing = ledger {
                    // `normalize` は日付が変わっていれば台帳を作り直し、この直後の
                    // `writeLedger` が前日分をディスクから消す。読み取り目的の `load` でも
                    // 同じ経路を通るため、切り出しはここでしか確実に挟めない。
                    let currentDayOrdinal = ScreenTimeDateMath.localDayOrdinal(
                        for: referenceDate,
                        calendar: calendar
                    )
                    if existing.localDayOrdinal(calendar: calendar) < currentDayOrdinal {
                        // ここでフックを呼ぶと、フック側の別ファイルへの協調要求が
                        // この書き込みクレームの内側で走り、デッドロックしうる。
                        // 中身だけ退避し、協調ブロックを抜けてから引き渡す。
                        staleLedger = existing
                    }
                    existing.normalize(
                        settings: settings,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                    ledger = existing
                }
                let result = try operation(&ledger)
                if let ledger {
                    try writeLedger(ledger, to: coordinatedURL)
                }
                operationResult = .success(result)
            } catch {
                operationResult = .failure(error)
            }
        }

        // 書き込みクレームを手放してから引き渡す。中身は退避済みなので、
        // 書き戻しが先に走っていても前日分の内容は失われない。
        if let staleLedger {
            staleDayHandler?(staleLedger)
        }

        if coordinationError != nil {
            throw ScreenTimeTicketLedgerStoreError.coordinationFailed
        }
        guard let operationResult else {
            throw ScreenTimeTicketLedgerStoreError.coordinationFailed
        }
        return try operationResult.get()
    }

    private func readLedger(at url: URL) throws -> ScreenTimeTicketLedger? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(ScreenTimeTicketLedger.self, from: Data(contentsOf: url))
        } catch {
            throw ScreenTimeTicketLedgerStoreError.stateReadFailed
        }
    }

    private func writeLedger(_ ledger: ScreenTimeTicketLedger, to url: URL) throws {
        do {
            let data = try JSONEncoder().encode(ledger)
            try data.write(to: url, options: .atomic)
        } catch {
            throw ScreenTimeTicketLedgerStoreError.stateWriteFailed
        }
    }
}
