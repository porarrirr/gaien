import Foundation

/// 1日分の記録。日付が変わるときに台帳から切り出して保存する。
///
/// `usageMinutes` は `DeviceActivityEvent` のしきい値到達から得た下限であり、
/// 実際の使用時間はこれ以上になりうる。UI では「目安」として扱う。
struct ScreenTimeDayRecord: Codable, Equatable, Identifiable {
    var dayOrdinal: Int
    var dayStart: Int64
    var allowanceMinutes: Int
    var usageMinutes: Int
    var baseMinutes: Int
    var earnedMinutes: Int
    var bonusMinutes: Int
    var ticketsUsed: Int
    var ticketsIssued: Int
    var shieldInteractions: Int
    var studyMinutes: Int
    var goalTargetMinutes: Int
    var protectionInterrupted: Bool

    var id: Int { dayOrdinal }

    init(
        dayOrdinal: Int,
        dayStart: Int64,
        allowanceMinutes: Int,
        usageMinutes: Int,
        baseMinutes: Int,
        earnedMinutes: Int,
        bonusMinutes: Int,
        ticketsUsed: Int,
        ticketsIssued: Int,
        shieldInteractions: Int,
        studyMinutes: Int,
        goalTargetMinutes: Int,
        protectionInterrupted: Bool
    ) {
        self.dayOrdinal = dayOrdinal
        self.dayStart = dayStart
        self.allowanceMinutes = allowanceMinutes
        self.usageMinutes = usageMinutes
        self.baseMinutes = baseMinutes
        self.earnedMinutes = earnedMinutes
        self.bonusMinutes = bonusMinutes
        self.ticketsUsed = ticketsUsed
        self.ticketsIssued = ticketsIssued
        self.shieldInteractions = shieldInteractions
        self.studyMinutes = studyMinutes
        self.goalTargetMinutes = goalTargetMinutes
        self.protectionInterrupted = protectionInterrupted
    }

    init(ledger: ScreenTimeTicketLedger, calendar: Calendar = .current) {
        let dayStartDate = ScreenTimeDateMath.date(fromEpochMilliseconds: ledger.dayStart)
        self.init(
            dayOrdinal: ledger.issuedLocalDayOrdinal
                ?? ScreenTimeDateMath.localDayOrdinal(for: dayStartDate, calendar: calendar),
            dayStart: ledger.dayStart,
            allowanceMinutes: ledger.totalAllowanceMinutes,
            usageMinutes: max(ledger.usageMilestoneMinutes, 0),
            baseMinutes: max(ledger.baseAllowanceMinutes, 0),
            earnedMinutes: max(ledger.earnedAllowanceMinutes, 0),
            bonusMinutes: max(ledger.bonusAllowanceMinutes, 0),
            ticketsUsed: max(ledger.usedTicketCount, 0),
            ticketsIssued: max(ledger.issuedTicketCount, 0),
            shieldInteractions: max(ledger.shieldInteractionCount, 0),
            studyMinutes: max(ledger.studyMinutes, 0),
            goalTargetMinutes: max(ledger.goalTargetMinutes, 0),
            protectionInterrupted: ledger.protectionInterrupted
        )
    }

    var goalReached: Bool {
        goalTargetMinutes > 0 && studyMinutes >= goalTargetMinutes
    }

    var exceededAllowance: Bool {
        allowanceMinutes > 0 && usageMinutes >= allowanceMinutes
    }

    /// 記録として意味があるか（制限を使っていた日か）。
    var isMeaningful: Bool {
        allowanceMinutes > 0
            || usageMinutes > 0
            || ticketsIssued > 0
            || ticketsUsed > 0
            || shieldInteractions > 0
            || studyMinutes > 0
            || protectionInterrupted
    }

    var date: Date {
        ScreenTimeDateMath.date(fromEpochMilliseconds: dayStart)
    }
}

/// 直近35日分のリングバッファ。
struct ScreenTimeUsageHistory: Codable, Equatable {
    static let maximumDayCount = 35

    /// 日付昇順。
    var days: [ScreenTimeDayRecord]

    init(days: [ScreenTimeDayRecord] = []) {
        self.days = days.sorted { $0.dayOrdinal < $1.dayOrdinal }
    }

    mutating func upsert(_ record: ScreenTimeDayRecord) {
        guard record.isMeaningful else { return }
        if let index = days.firstIndex(where: { $0.dayOrdinal == record.dayOrdinal }) {
            days[index] = record
        } else {
            days.append(record)
            days.sort { $0.dayOrdinal < $1.dayOrdinal }
        }
        if days.count > Self.maximumDayCount {
            days.removeFirst(days.count - Self.maximumDayCount)
        }
    }

    func record(forDayOrdinal ordinal: Int) -> ScreenTimeDayRecord? {
        days.first { $0.dayOrdinal == ordinal }
    }
}

/// レポート表示用の1日枠。記録が無い日も枠として並べる（0分と区別する）。
struct ScreenTimeUsageDaySlot: Identifiable, Equatable {
    var date: Date
    var dayOrdinal: Int
    var record: ScreenTimeDayRecord?

    var id: Int { dayOrdinal }

    var usageMinutes: Int { record?.usageMinutes ?? 0 }
    var allowanceMinutes: Int { record?.allowanceMinutes ?? 0 }
    var studyMinutes: Int { record?.studyMinutes ?? 0 }
    var ticketsUsed: Int { record?.ticketsUsed ?? 0 }
    var shieldInteractions: Int { record?.shieldInteractions ?? 0 }
    var hasRecord: Bool { record != nil }
}

/// 週次サマリ。今日は台帳から、過去は履歴から組み立てる。
struct ScreenTimeUsageSummary: Equatable {
    var slots: [ScreenTimeUsageDaySlot]
    var recordedDayCount: Int
    var totalUsageMinutes: Int
    var totalStudyMinutes: Int
    var totalTicketsUsed: Int
    var totalShieldInteractions: Int
    var exceededDayCount: Int
    var interruptedDayCount: Int
    var previousAverageUsageMinutes: Int?

    var averageUsageMinutes: Int {
        guard recordedDayCount > 0 else { return 0 }
        return Int((Double(totalUsageMinutes) / Double(recordedDayCount)).rounded())
    }

    /// 前の同じ期間との差（分）。マイナスなら減っている。
    var usageDeltaMinutes: Int? {
        guard let previousAverageUsageMinutes, recordedDayCount > 0 else { return nil }
        return averageUsageMinutes - previousAverageUsageMinutes
    }

    var hasData: Bool {
        recordedDayCount > 0
    }

    static let empty = ScreenTimeUsageSummary(
        slots: [],
        recordedDayCount: 0,
        totalUsageMinutes: 0,
        totalStudyMinutes: 0,
        totalTicketsUsed: 0,
        totalShieldInteractions: 0,
        exceededDayCount: 0,
        interruptedDayCount: 0,
        previousAverageUsageMinutes: nil
    )

    static func make(
        history: ScreenTimeUsageHistory,
        today: ScreenTimeDayRecord?,
        dayCount: Int = 7,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> ScreenTimeUsageSummary {
        var merged = history
        if let today {
            merged.upsert(today)
        }

        let slots = daySlots(
            history: merged,
            dayCount: dayCount,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let recorded = slots.compactMap(\.record).filter(\.isMeaningful)

        let previousSlots = daySlots(
            history: merged,
            dayCount: dayCount,
            referenceDate: calendar.date(byAdding: .day, value: -dayCount, to: referenceDate) ?? referenceDate,
            calendar: calendar
        )
        let previousRecorded = previousSlots.compactMap(\.record).filter(\.isMeaningful)
        let previousAverage: Int? = previousRecorded.isEmpty
            ? nil
            : Int((Double(previousRecorded.reduce(0) { $0 + $1.usageMinutes }) / Double(previousRecorded.count)).rounded())

        return ScreenTimeUsageSummary(
            slots: slots,
            recordedDayCount: recorded.count,
            totalUsageMinutes: recorded.reduce(0) { $0 + $1.usageMinutes },
            totalStudyMinutes: recorded.reduce(0) { $0 + $1.studyMinutes },
            totalTicketsUsed: recorded.reduce(0) { $0 + $1.ticketsUsed },
            totalShieldInteractions: recorded.reduce(0) { $0 + $1.shieldInteractions },
            exceededDayCount: recorded.filter(\.exceededAllowance).count,
            interruptedDayCount: recorded.filter(\.protectionInterrupted).count,
            previousAverageUsageMinutes: previousAverage
        )
    }

    private static func daySlots(
        history: ScreenTimeUsageHistory,
        dayCount: Int,
        referenceDate: Date,
        calendar: Calendar
    ) -> [ScreenTimeUsageDaySlot] {
        let todayStart = calendar.startOfDay(for: referenceDate)
        return (0..<max(dayCount, 1)).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            let ordinal = ScreenTimeDateMath.localDayOrdinal(for: date, calendar: calendar)
            let record = history.record(forDayOrdinal: ordinal)
            return ScreenTimeUsageDaySlot(
                date: date,
                dayOrdinal: ordinal,
                record: record?.isMeaningful == true ? record : nil
            )
        }
    }
}

enum ScreenTimeUsageHistoryStoreError: LocalizedError {
    case appGroupUnavailable
    case coordinationFailed
    case readFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "利用記録の共有保存領域を利用できません"
        case .coordinationFailed:
            return "利用記録を安全に更新できませんでした"
        case .readFailed:
            return "利用記録を読み込めませんでした"
        case .writeFailed:
            return "利用記録を保存できませんでした"
        }
    }
}

struct ScreenTimeUsageHistoryStore {
    typealias FileURLProvider = () -> URL?

    private let fileURLProvider: FileURLProvider

    init(fileURLProvider: @escaping FileURLProvider = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ScreenTimeFocusShared.appGroupIdentifier)?
            .appendingPathComponent("screen-time-usage-history-v1.json", isDirectory: false)
    }) {
        self.fileURLProvider = fileURLProvider
    }

    /// 表示専用の読み取り。台帳と同じ理由で協調を使わない（`.atomic` 書き込みのため安全）。
    func loadReadOnly() throws -> ScreenTimeUsageHistory {
        guard let fileURL = fileURLProvider() else {
            throw ScreenTimeUsageHistoryStoreError.appGroupUnavailable
        }
        return try readHistory(at: fileURL) ?? ScreenTimeUsageHistory()
    }

    @discardableResult
    func update<T>(_ update: (inout ScreenTimeUsageHistory) throws -> T) throws -> T {
        guard let fileURL = fileURLProvider() else {
            throw ScreenTimeUsageHistoryStoreError.appGroupUnavailable
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationResult: Result<T, Error>?
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                var history = try readHistory(at: coordinatedURL) ?? ScreenTimeUsageHistory()
                let result = try update(&history)
                try writeHistory(history, to: coordinatedURL)
                operationResult = .success(result)
            } catch {
                operationResult = .failure(error)
            }
        }

        if coordinationError != nil {
            throw ScreenTimeUsageHistoryStoreError.coordinationFailed
        }
        guard let operationResult else {
            throw ScreenTimeUsageHistoryStoreError.coordinationFailed
        }
        return try operationResult.get()
    }

    private func readHistory(at url: URL) throws -> ScreenTimeUsageHistory? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(ScreenTimeUsageHistory.self, from: Data(contentsOf: url))
        } catch {
            throw ScreenTimeUsageHistoryStoreError.readFailed
        }
    }

    private func writeHistory(_ history: ScreenTimeUsageHistory, to url: URL) throws {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: url, options: .atomic)
        } catch {
            throw ScreenTimeUsageHistoryStoreError.writeFailed
        }
    }
}
