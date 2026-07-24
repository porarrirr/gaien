import Foundation

enum ScreenTimeTicketLedgerMutationError: Error, Equatable {
    case activeTicket
    case noTicketsRemaining
    case notCurrentDay
}

struct ScreenTimeTicketLedger: Codable, Equatable {
    var dayStart: Int64
    /// Gregorian-style local date ordinal (yyyyMMdd) used to prevent reissuing
    /// tickets when the device clock or time zone moves backwards.
    var issuedLocalDayOrdinal: Int? = nil
    var issuedTicketCount: Int
    var usedTicketCount: Int
    var activeTicketStartedAt: Int64?
    var activeTicketEndsAt: Int64?
    var updatedAt: Int64

    static func make(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> ScreenTimeTicketLedger {
        ScreenTimeTicketLedger(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: referenceDate)),
            issuedLocalDayOrdinal: localDayOrdinal(for: referenceDate, calendar: calendar),
            issuedTicketCount: settings.dailyTicketMinutes / ScreenTimeFocusSettings.ticketDurationMinutes,
            usedTicketCount: 0,
            activeTicketStartedAt: nil,
            activeTicketEndsAt: nil,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: referenceDate)
        )
    }

    var remainingTicketCount: Int {
        max(issuedTicketCount - usedTicketCount, 0)
    }

    var activeTicketEndDate: Date? {
        guard let activeTicketEndsAt else { return nil }
        return ScreenTimeDateMath.date(fromEpochMilliseconds: activeTicketEndsAt)
    }

    func isForDay(containing date: Date, calendar: Calendar = .current) -> Bool {
        effectiveIssuedLocalDayOrdinal(calendar: calendar)
            == Self.localDayOrdinal(for: date, calendar: calendar)
    }

    func hasActiveTicket(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isForDay(containing: date, calendar: calendar),
              let activeTicketEndsAt else {
            return false
        }
        return ScreenTimeDateMath.epochMilliseconds(for: date) < activeTicketEndsAt
    }

    mutating func reserveTicket(start: Date, expiry: Date, calendar: Calendar = .current) throws {
        guard isForDay(containing: start, calendar: calendar) else {
            throw ScreenTimeTicketLedgerMutationError.notCurrentDay
        }
        guard !hasActiveTicket(at: start, calendar: calendar) else {
            throw ScreenTimeTicketLedgerMutationError.activeTicket
        }
        guard remainingTicketCount > 0 else {
            throw ScreenTimeTicketLedgerMutationError.noTicketsRemaining
        }
        usedTicketCount += 1
        activeTicketStartedAt = ScreenTimeDateMath.epochMilliseconds(for: start)
        activeTicketEndsAt = ScreenTimeDateMath.epochMilliseconds(for: expiry)
        updatedAt = ScreenTimeDateMath.epochMilliseconds(for: start)
    }

    mutating func normalize(
        settings: ScreenTimeFocusSettings,
        referenceDate: Date,
        calendar: Calendar = .current
    ) {
        let currentDayOrdinal = Self.localDayOrdinal(for: referenceDate, calendar: calendar)
        if currentDayOrdinal > effectiveIssuedLocalDayOrdinal(calendar: calendar) {
            self = Self.make(settings: settings, referenceDate: referenceDate, calendar: calendar)
            return
        }
        if issuedLocalDayOrdinal == nil {
            issuedLocalDayOrdinal = effectiveIssuedLocalDayOrdinal(calendar: calendar)
        }
        if !isForDay(containing: referenceDate, calendar: calendar)
            || !hasActiveTicket(at: referenceDate, calendar: calendar) {
            activeTicketStartedAt = nil
            activeTicketEndsAt = nil
        }
        updatedAt = ScreenTimeDateMath.epochMilliseconds(for: referenceDate)
    }

    private func effectiveIssuedLocalDayOrdinal(calendar: Calendar) -> Int {
        issuedLocalDayOrdinal
            ?? Self.localDayOrdinal(
                for: ScreenTimeDateMath.date(fromEpochMilliseconds: dayStart),
                calendar: calendar
            )
    }

    private static func localDayOrdinal(for date: Date, calendar: Calendar) -> Int {
        var localGregorianCalendar = Calendar(identifier: .gregorian)
        localGregorianCalendar.timeZone = calendar.timeZone
        let components = localGregorianCalendar.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)
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

    private let fileURLProvider: FileURLProvider

    init(fileURLProvider: @escaping FileURLProvider = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ScreenTimeFocusShared.appGroupIdentifier)?
            .appendingPathComponent("screen-time-ticket-ledger-v1.json", isDirectory: false)
    }) {
        self.fileURLProvider = fileURLProvider
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
        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                var ledger = try readLedger(at: coordinatedURL)
                if var existing = ledger {
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
