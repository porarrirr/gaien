import Combine
import Foundation

@MainActor
final class TimetableViewModel: ScreenViewModel {
    @Published private(set) var periods: [TimetablePeriod] = []
    @Published private(set) var entries: [TimetableEntry] = []
    @Published private(set) var terms: [TimetableTerm] = []
    @Published private(set) var reviewRecords: [TimetableReviewRecord] = []
    @Published var selectedTermId: Int64?
    @Published var selectedDate = Date().startOfDay
    @Published var displayedMonth = Date().startOfMonth

    var entriesBySlot: [TimetableSlotKey: TimetableEntry] {
        entriesForSelectedTerm(activeOn: Date().startOfDay).reduce(into: [TimetableSlotKey: TimetableEntry]()) { result, entry in
            let key = TimetableSlotKey(day: entry.dayOfWeek, periodId: entry.periodId)
            if let existing = result[key], existing.updatedAt > entry.updatedAt {
                return
            }
            result[key] = entry
        }
    }

    var selectedTerm: TimetableTerm? {
        terms.first { $0.id == selectedTermId } ?? terms.first
    }

    private var allEntriesForSelectedTerm: [TimetableEntry] {
        guard let selectedTerm else { return [] }
        return entries.filter { entry in
            entry.termId == selectedTerm.id || entry.termId == nil
        }
    }

    var selectedDateOccurrences: [TimetableReviewOccurrence] {
        guard let selectedTerm else { return [] }
        return occurrences(on: selectedDate, in: selectedTerm)
    }

    var termSummary: TimetableReviewSummary {
        guard let selectedTerm else { return .empty }
        return summary(for: selectedTerm)
    }

    var pendingOccurrenceDaysInDisplayedMonth: Set<Int> {
        guard let selectedTerm else { return [] }
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }

        let monthStart = Swift.max(selectedTerm.startDateValue, monthInterval.start.startOfDay)
        let rawMonthEnd = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)?.startOfDay ?? monthInterval.start.startOfDay
        let monthEnd = Swift.min(selectedTerm.endDateValue, rawMonthEnd, Date().startOfDay)
        guard monthStart <= monthEnd else { return [] }

        var days = Set<Int>()
        var date = monthStart
        while date <= monthEnd {
            if occurrences(on: date, in: selectedTerm).contains(where: { $0.status == .pending || $0.status == .overdue }) {
                days.insert(calendar.component(.day, from: date))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }

    var occurrenceStatusByDayInDisplayedMonth: [Int: TimetableReviewStatus] {
        guard let selectedTerm else { return [:] }
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [:] }

        let monthStart = Swift.max(selectedTerm.startDateValue, monthInterval.start.startOfDay)
        let rawMonthEnd = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)?.startOfDay ?? monthInterval.start.startOfDay
        let monthEnd = Swift.min(selectedTerm.endDateValue, rawMonthEnd, Date().startOfDay)
        guard monthStart <= monthEnd else { return [:] }

        var statuses = [Int: TimetableReviewStatus]()
        var date = monthStart
        while date <= monthEnd {
            let occurrences = occurrences(on: date, in: selectedTerm)
            if !occurrences.isEmpty {
                statuses[calendar.component(.day, from: date)] = Self.combinedStatus(for: occurrences)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return statuses
    }

    func load() async {
        do {
            var loadedPeriods = try await app.timetableRepo.getAllTimetablePeriods()
            if loadedPeriods.isEmpty {
                for period in TimetablePeriod.defaultPeriods {
                    _ = try await app.timetableRepo.saveTimetablePeriod(period)
                }
                loadedPeriods = try await app.timetableRepo.getAllTimetablePeriods()
                app.bumpDataVersion()
            }
            periods = loadedPeriods
            terms = try await app.timetableRepo.getAllTimetableTerms()
            if terms.isEmpty {
                let defaultTerm = Self.defaultTerm()
                let id = try await app.timetableRepo.saveTimetableTerm(defaultTerm)
                terms = try await app.timetableRepo.getAllTimetableTerms()
                selectedTermId = id
                app.bumpDataVersion()
            } else if selectedTermId == nil || !terms.contains(where: { $0.id == selectedTermId }) {
                selectedTermId = Self.initialTerm(from: terms, reference: Date())?.id
            }
            entries = try await app.timetableRepo.getAllTimetableEntries()
            reviewRecords = try await app.timetableRepo.getAllTimetableReviewRecords()
            syncDisplayedMonthWithSelectedDateIfNeeded()
        } catch {
            app.present(error)
        }
    }

    func savePeriodDrafts(_ drafts: [TimetablePeriodDraft]) {
        perform {
            let activeIds = Set(drafts.map(\.period.syncId))
            for draft in drafts {
                guard draft.startMinute < draft.endMinute else {
                    throw ValidationError(message: "\(draft.name) の終了時刻は開始時刻より後にしてください")
                }
            }
            for period in self.periods where !activeIds.contains(period.syncId) {
                try await self.app.timetableRepo.deleteTimetablePeriod(period)
            }
            for (index, draft) in drafts.enumerated() {
                var period = draft.period
                period.sortOrder = index + 1
                period.updatedAt = Date().epochMilliseconds
                try await self.app.timetableRepo.saveTimetablePeriod(period)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func saveEntry(_ entry: TimetableEntry) {
        perform {
            if entry.id > 0 {
                let today = Date().startOfDay.epochDay
                let yesterday = today - 1
                var archivedEntry = self.entries.first(where: { $0.id == entry.id }) ?? entry
                archivedEntry.validToDate = yesterday
                archivedEntry.updatedAt = Date().epochMilliseconds
                var futureEntry = entry
                futureEntry.id = 0
                futureEntry.syncId = UUID().uuidString.lowercased()
                futureEntry.validFromDate = today
                futureEntry.validToDate = nil
                futureEntry.createdAt = Date().epochMilliseconds
                _ = try await self.app.timetableRepo.saveTimetableEntry(archivedEntry)
                _ = try await self.app.timetableRepo.saveTimetableEntry(futureEntry)
            } else {
                _ = try await self.app.timetableRepo.saveTimetableEntry(entry)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteEntry(_ entry: TimetableEntry) {
        perform {
            try await self.app.timetableRepo.deleteTimetableEntry(entry)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func saveTerm(_ term: TimetableTerm) {
        perform {
            let id = try await self.app.timetableRepo.saveTimetableTerm(term)
            self.selectedTermId = id
            self.selectedDate = term.contains(self.selectedDate) ? self.selectedDate : term.startDateValue
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func selectTerm(_ term: TimetableTerm) {
        selectedTermId = term.id
        if !term.contains(selectedDate) {
            selectedDate = term.contains(Date()) ? Date().startOfDay : term.startDateValue
        }
        syncDisplayedMonthWithSelectedDateIfNeeded()
    }

    func selectDate(_ date: Date) {
        selectedDate = date.startOfDay
        syncDisplayedMonthWithSelectedDateIfNeeded()
    }

    func moveDisplayedMonth(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = next.startOfMonth
    }

    func setReviewed(_ occurrence: TimetableReviewOccurrence, reviewed: Bool, note: String?) {
        perform {
            let now = Date().epochMilliseconds
            var record = occurrence.record ?? occurrence.makeRecord()
            record.isReviewed = reviewed
            record.isExcluded = false
            record.note = note?.nilIfBlank
            record.reviewedAt = reviewed ? now : nil
            record.updatedAt = now
            _ = try await self.app.timetableRepo.saveTimetableReviewRecord(record)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func setExcluded(_ occurrence: TimetableReviewOccurrence, excluded: Bool) {
        perform {
            let now = Date().epochMilliseconds
            var record = occurrence.record ?? occurrence.makeRecord()
            record.isExcluded = excluded
            if excluded {
                record.isReviewed = false
                record.reviewedAt = nil
            }
            record.updatedAt = now
            _ = try await self.app.timetableRepo.saveTimetableReviewRecord(record)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func isDateInSelectedTerm(_ date: Date) -> Bool {
        selectedTerm?.contains(date) ?? false
    }

    private func occurrences(on date: Date, in term: TimetableTerm) -> [TimetableReviewOccurrence] {
        let occurrenceDay = date.startOfDay.epochDay
        guard term.startDate <= occurrenceDay && occurrenceDay <= term.endDate else { return [] }
        let weekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: date))
        let periodMap = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })
        return allEntriesForSelectedTerm
            .filter { $0.dayOfWeek == weekday && $0.deletedAt == nil && isEntry($0, activeOn: date) }
            .compactMap { entry -> TimetableReviewOccurrence? in
                guard let period = periodMap[entry.periodId] else { return nil }
                let record = reviewRecords.first {
                    $0.termId == term.id &&
                    $0.entryId == entry.id &&
                    $0.periodId == period.id &&
                    $0.occurrenceDate == occurrenceDay &&
                    $0.deletedAt == nil
                }
                return TimetableReviewOccurrence(term: term, entry: entry, period: period, occurrenceDate: occurrenceDay, record: record)
            }
            .sorted { $0.period.startMinute < $1.period.startMinute }
    }

    private func summary(for term: TimetableTerm) -> TimetableReviewSummary {
        let calendar = Calendar.current
        var date = term.startDateValue
        let endDate = Swift.min(term.endDateValue, Date().startOfDay)
        var allOccurrences = [TimetableReviewOccurrence]()
        while date <= endDate {
            allOccurrences.append(contentsOf: occurrences(on: date, in: term))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        let reviewed = allOccurrences.filter { $0.status == .reviewed }.count
        let excluded = allOccurrences.filter { $0.status == .excluded }.count
        let pending = allOccurrences.filter { $0.status == .pending || $0.status == .overdue }.count
        return TimetableReviewSummary(total: allOccurrences.count, reviewed: reviewed, excluded: excluded, pending: pending)
    }

    private func isEntry(_ entry: TimetableEntry, activeOn date: Date) -> Bool {
        let day = date.startOfDay.epochDay
        if let validFromDate = entry.validFromDate, day < validFromDate {
            return false
        }
        if let validToDate = entry.validToDate, day > validToDate {
            return false
        }
        return true
    }

    private func entriesForSelectedTerm(activeOn date: Date) -> [TimetableEntry] {
        allEntriesForSelectedTerm.filter { $0.deletedAt == nil && isEntry($0, activeOn: date) }
    }

    private func syncDisplayedMonthWithSelectedDateIfNeeded() {
        let selectedMonth = selectedDate.startOfMonth
        if !Calendar.current.isDate(displayedMonth, equalTo: selectedMonth, toGranularity: .month) {
            displayedMonth = selectedMonth
        }
    }

    private static func defaultTerm() -> TimetableTerm {
        let today = Date().startOfDay
        let end = Calendar.current.date(byAdding: .month, value: 6, to: today) ?? today
        return TimetableTerm(name: "現在の学期", startDate: today.epochDay, endDate: end.epochDay)
    }

    private static func initialTerm(from terms: [TimetableTerm], reference: Date) -> TimetableTerm? {
        if let current = terms.first(where: { $0.contains(reference) }) {
            return current
        }
        return terms.sorted { $0.endDate > $1.endDate }.first
    }

    private static func combinedStatus(for occurrences: [TimetableReviewOccurrence]) -> TimetableReviewStatus {
        if occurrences.contains(where: { $0.status == .pending || $0.status == .overdue }) {
            return .pending
        }
        if occurrences.allSatisfy({ $0.status == .excluded }) {
            return .excluded
        }
        if occurrences.contains(where: { $0.status == .reviewed }) {
            return .reviewed
        }
        return .notAvailable
    }
}

private extension Date {
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)?.startOfDay ?? startOfDay
    }
}

struct TimetableSlotKey: Hashable {
    var day: StudyWeekday
    var periodId: Int64
}

struct TimetablePeriodDraft: Identifiable, Hashable {
    var period: TimetablePeriod

    var id: String { period.syncId }
    var name: String {
        get { period.name }
        set { period.name = newValue }
    }
    var startMinute: Int { period.startMinute }
    var endMinute: Int { period.endMinute }

    init(period: TimetablePeriod) {
        self.period = period
    }

    init(order: Int, startMinute: Int, endMinute: Int) {
        self.period = TimetablePeriod(
            name: "\(order)限",
            startMinute: startMinute,
            endMinute: endMinute,
            sortOrder: order
        )
    }

    var startDate: Date {
        get { Self.date(from: period.startMinute) }
        set { period.startMinute = Self.minute(from: newValue) }
    }

    var endDate: Date {
        get { Self.date(from: period.endMinute) }
        set { period.endMinute = Self.minute(from: newValue) }
    }

    private static func date(from minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func minute(from date: Date) -> Int {
        let calendar = Calendar.current
        let rawMinute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return (rawMinute / 5) * 5
    }
}

struct TimetableReviewSummary: Hashable {
    var total: Int
    var reviewed: Int
    var excluded: Int
    var pending: Int

    var completionRate: Double {
        let denominator = Swift.max(total - excluded, 0)
        guard denominator > 0 else { return 0 }
        return Double(reviewed) / Double(denominator)
    }

    static let empty = TimetableReviewSummary(total: 0, reviewed: 0, excluded: 0, pending: 0)
}

enum TimetableReviewStatus: Hashable {
    case notAvailable
    case pending
    case overdue
    case reviewed
    case excluded
}

struct TimetableReviewOccurrence: Identifiable, Hashable {
    var term: TimetableTerm
    var entry: TimetableEntry
    var period: TimetablePeriod
    var occurrenceDate: Int64
    var record: TimetableReviewRecord?

    var id: String {
        "\(term.id)-\(entry.id)-\(period.id)-\(occurrenceDate)"
    }

    var date: Date {
        Date(epochDay: occurrenceDate)
    }

    var canReview: Bool {
        Date() >= occurrenceEndDate
    }

    var occurrenceEndDate: Date {
        Calendar.current.date(
            bySettingHour: period.endMinute / 60,
            minute: period.endMinute % 60,
            second: 0,
            of: date
        ) ?? date
    }

    var isDeadlineExceeded: Bool {
        guard !isReviewed && !isExcluded else { return false }
        let deadline = occurrenceEndDate.addingTimeInterval(48 * 60 * 60)
        return Date() >= deadline
    }

    var isReviewed: Bool {
        record?.isReviewed == true
    }

    var isExcluded: Bool {
        record?.isExcluded == true
    }

    var status: TimetableReviewStatus {
        if isExcluded { return .excluded }
        if isReviewed { return .reviewed }
        if !canReview { return .notAvailable }
        return isDeadlineExceeded ? .overdue : .pending
    }

    func makeRecord() -> TimetableReviewRecord {
        TimetableReviewRecord(
            termId: term.id,
            termSyncId: term.syncId,
            entryId: entry.id,
            entrySyncId: entry.syncId,
            periodId: period.id,
            periodSyncId: period.syncId,
            occurrenceDate: occurrenceDate,
            dayOfWeek: entry.dayOfWeek,
            periodName: period.name,
            periodStartMinute: period.startMinute,
            periodEndMinute: period.endMinute,
            subjectName: entry.subjectName,
            courseName: entry.courseName,
            roomName: entry.roomName
        )
    }
}
