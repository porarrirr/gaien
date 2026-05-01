import Combine
import Foundation

@MainActor
final class CalendarViewModel: ScreenViewModel {
    @Published private(set) var monthStudyMap: [Int: Int] = [:]
    @Published private(set) var daySessionsMap: [Int: [StudySession]] = [:]
    @Published private(set) var materials: [Material] = []
    @Published private(set) var timetablePeriods: [TimetablePeriod] = []
    @Published private(set) var timetableEntries: [TimetableEntry] = []
    @Published private(set) var timetableTerms: [TimetableTerm] = []
    @Published var displayedMonth = Date()

    func load() async {
        do {
            let monthInterval = Calendar.current.dateInterval(of: .month, for: displayedMonth)
            let start = monthInterval?.start ?? displayedMonth.startOfDay
            let end = monthInterval?.end ?? displayedMonth
            async let sessionsTask = app.persistence.getSessionsBetweenDates(
                start: start.epochMilliseconds,
                end: end.epochMilliseconds
            )
            async let materialsTask = app.persistence.getAllMaterials()
            async let timetablePeriodsTask = app.persistence.getAllTimetablePeriods()
            async let timetableEntriesTask = app.persistence.getAllTimetableEntries()
            async let timetableTermsTask = app.persistence.getAllTimetableTerms()
            let sessions = try await sessionsTask
            materials = try await materialsTask
            timetablePeriods = try await timetablePeriodsTask
            timetableEntries = try await timetableEntriesTask
            timetableTerms = try await timetableTermsTask
            let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }

            monthStudyMap = sortedSessions.reduce(into: [:]) { result, session in
                let day = Calendar.current.component(.day, from: session.startDate)
                result[day, default: 0] += session.durationMinutes
            }
            daySessionsMap = Dictionary(grouping: sortedSessions) { session in
                Calendar.current.component(.day, from: session.startDate)
            }
        } catch {
            app.present(error)
        }
    }

    func sessions(for day: Int) -> [StudySession] {
        daySessionsMap[day] ?? []
    }

    func subjectSummaries(for day: Int) -> [DayStudySubjectSummary] {
        DayStudySubjectSummary.make(from: sessions(for: day))
    }

    func totalMinutes(for day: Int) -> Int {
        sessions(for: day).reduce(0) { $0 + $1.durationMinutes }
    }

    func timelineItems(for day: Int, referenceDate: Date = Date()) -> [CalendarTimelineItem] {
        guard let date = Calendar.current.date(
            from: DateComponents(year: displayYear, month: displayMonth, day: day)
        ) else { return [] }

        let sessions = sessions(for: day)
        let studyItems = sessions.map(CalendarTimelineItem.study)
        let lessonItems = lessons(on: date).map(CalendarTimelineItem.lesson)
        let occupiedBlocks = (studyItems + lessonItems)
            .flatMap(\.occupiedIntervals)
            .sorted { $0.startTime < $1.startTime }
        let mergedOccupiedBlocks = Self.mergeIntervals(occupiedBlocks)
        let displayWindow = Self.displayWindow(
            for: date,
            occupiedBlocks: mergedOccupiedBlocks,
            referenceDate: referenceDate
        )
        let gapItems = Self.gaps(
            in: displayWindow,
            excluding: mergedOccupiedBlocks
        ).map(CalendarTimelineItem.gap)

        return (studyItems + lessonItems + gapItems).sorted { left, right in
            if left.startTime == right.startTime {
                return left.sortPriority < right.sortPriority
            }
            return left.startTime < right.startTime
        }
    }

    func materialProblemCount(for session: StudySession) -> Int {
        material(for: session)?.effectiveTotalProblems ?? 0
    }

    func materialProblemChapters(for session: StudySession) -> [ProblemChapter] {
        material(for: session)?.problemChapters ?? []
    }

    func material(for session: StudySession) -> Material? {
        guard let materialId = session.materialId else { return nil }
        return materials.first(where: { $0.id == materialId })
    }

    func updateSession(
        _ session: StudySession,
        intervals: [StudySessionInterval],
        note: String?,
        rating: Int?,
        problemStart: Int? = nil,
        problemEnd: Int? = nil,
        wrongProblemCount: Int? = nil,
        problemRecords: [ProblemSessionRecord] = []
    ) {
        perform {
            guard !intervals.isEmpty else { throw ValidationError(message: "学習時間を入力してください") }
            guard intervals.allSatisfy({ $0.endTime > $0.startTime }) else {
                throw ValidationError(message: "終了時刻は開始時刻より後にしてください")
            }
            let sortedIntervals = intervals.sorted { $0.startTime < $1.startTime }
            for index in sortedIntervals.indices.dropFirst() where sortedIntervals[index].startTime < sortedIntervals[index - 1].endTime {
                throw ValidationError(message: "学習区間が重ならないようにしてください")
            }
            var updated = session
            updated.startTime = sortedIntervals[0].startTime
            updated.endTime = sortedIntervals[sortedIntervals.count - 1].endTime
            updated.intervals = sortedIntervals
            updated.note = note?.nilIfBlank
            updated.rating = rating
            updated.problemStart = problemStart
            updated.problemEnd = problemEnd
            updated.wrongProblemCount = wrongProblemCount
            updated.problemRecords = problemRecords
            try await self.app.persistence.updateSession(updated)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteSession(_ session: StudySession) {
        perform {
            try await self.app.persistence.deleteSession(session)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    private var displayYear: Int {
        Calendar.current.component(.year, from: displayedMonth)
    }

    private var displayMonth: Int {
        Calendar.current.component(.month, from: displayedMonth)
    }

    private func lessons(on date: Date) -> [CalendarTimelineLesson] {
        let dayStart = date.startOfDay
        let weekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: dayStart))
        let activeTerms = timetableTerms.filter { $0.contains(dayStart) }
        let activeTermIds = Set(activeTerms.map(\.id))
        let periodMap = Dictionary(uniqueKeysWithValues: timetablePeriods.map { ($0.id, $0) })

        return timetableEntries
            .filter { entry in
                entry.deletedAt == nil &&
                entry.dayOfWeek == weekday &&
                (entry.termId == nil || activeTermIds.contains(entry.termId ?? 0)) &&
                Self.isEntry(entry, activeOn: dayStart)
            }
            .compactMap { entry -> CalendarTimelineLesson? in
                guard let period = periodMap[entry.periodId] else { return nil }
                let start = Self.timestamp(on: dayStart, minute: period.startMinute)
                let end = Self.timestamp(on: dayStart, minute: period.endMinute)
                return CalendarTimelineLesson(entry: entry, period: period, startTime: start, endTime: end)
            }
            .sorted { $0.startTime < $1.startTime }
    }

    private static func isEntry(_ entry: TimetableEntry, activeOn date: Date) -> Bool {
        let day = date.startOfDay.epochDay
        if let validFromDate = entry.validFromDate, day < validFromDate {
            return false
        }
        if let validToDate = entry.validToDate, day > validToDate {
            return false
        }
        return true
    }

    private static func timestamp(on date: Date, minute: Int) -> Int64 {
        let calendar = Calendar.current
        let hour = minute / 60
        let minuteOfHour = minute % 60
        return (calendar.date(bySettingHour: hour, minute: minuteOfHour, second: 0, of: date.startOfDay) ?? date.startOfDay).epochMilliseconds
    }

    private static func displayWindow(
        for date: Date,
        occupiedBlocks: [StudySessionInterval],
        referenceDate: Date
    ) -> StudySessionInterval? {
        guard !occupiedBlocks.isEmpty else { return nil }
        let start = timestamp(on: date, minute: 5 * 60)
        let end: Int64
        if Calendar.current.isDate(date, inSameDayAs: referenceDate) {
            end = max(referenceDate.epochMilliseconds, occupiedBlocks.last?.endTime ?? start)
        } else {
            end = max(timestamp(on: date, minute: 23 * 60 + 59), occupiedBlocks.last?.endTime ?? start)
        }
        guard end > start else { return nil }
        return StudySessionInterval(startTime: start, endTime: end)
    }

    private static func gaps(
        in displayWindow: StudySessionInterval?,
        excluding occupiedBlocks: [StudySessionInterval]
    ) -> [CalendarTimelineGap] {
        guard let displayWindow else { return [] }
        var cursor = displayWindow.startTime
        var gaps: [CalendarTimelineGap] = []

        for block in occupiedBlocks {
            let blockStart = max(block.startTime, displayWindow.startTime)
            let blockEnd = min(block.endTime, displayWindow.endTime)
            guard blockEnd > displayWindow.startTime && blockStart < displayWindow.endTime else { continue }
            if blockStart > cursor {
                gaps.append(CalendarTimelineGap(startTime: cursor, endTime: blockStart))
            }
            cursor = max(cursor, blockEnd)
        }
        if displayWindow.endTime > cursor {
            gaps.append(CalendarTimelineGap(startTime: cursor, endTime: displayWindow.endTime))
        }
        return gaps.filter { $0.durationMilliseconds >= 60_000 }
    }

    private static func mergeIntervals(_ intervals: [StudySessionInterval]) -> [StudySessionInterval] {
        intervals.reduce(into: [StudySessionInterval]()) { result, interval in
            guard interval.endTime > interval.startTime else { return }
            if let last = result.last, interval.startTime <= last.endTime {
                result[result.count - 1] = StudySessionInterval(
                    startTime: last.startTime,
                    endTime: max(last.endTime, interval.endTime)
                )
            } else {
                result.append(interval)
            }
        }
    }
}

enum CalendarTimelineItem: Identifiable, Hashable {
    case gap(CalendarTimelineGap)
    case lesson(CalendarTimelineLesson)
    case study(StudySession)

    var id: String {
        switch self {
        case .gap(let gap): return "gap-\(gap.startTime)-\(gap.endTime)"
        case .lesson(let lesson): return "lesson-\(lesson.entry.id)-\(lesson.period.id)-\(lesson.startTime)"
        case .study(let session): return "study-\(session.id)-\(session.sessionStartTime)"
        }
    }

    var startTime: Int64 {
        switch self {
        case .gap(let gap): return gap.startTime
        case .lesson(let lesson): return lesson.startTime
        case .study(let session): return session.sessionStartTime
        }
    }

    var sortPriority: Int {
        switch self {
        case .lesson: return 0
        case .study: return 1
        case .gap: return 2
        }
    }

    var occupiedIntervals: [StudySessionInterval] {
        switch self {
        case .gap:
            return []
        case .lesson(let lesson):
            return [StudySessionInterval(startTime: lesson.startTime, endTime: lesson.endTime)]
        case .study(let session):
            return session.effectiveIntervals
        }
    }
}

struct CalendarTimelineGap: Hashable {
    var startTime: Int64
    var endTime: Int64

    var durationMilliseconds: Int64 {
        max(endTime - startTime, 0)
    }
}

struct CalendarTimelineLesson: Hashable {
    var entry: TimetableEntry
    var period: TimetablePeriod
    var startTime: Int64
    var endTime: Int64
}

struct DayStudySubjectSummary: Identifiable, Hashable {
    var id: String
    var subjectName: String
    var totalMinutes: Int
    var sessionCount: Int
    var materials: [DayStudyMaterialSummary]

    static func make(from sessions: [StudySession]) -> [DayStudySubjectSummary] {
        let subjectGroups = Dictionary(grouping: sessions) { session in
            "\(session.subjectId)|\(session.subjectName)"
        }

        return subjectGroups.map { _, subjectSessions in
            let sortedSubjectSessions = subjectSessions.sorted { $0.sessionStartTime < $1.sessionStartTime }
            let firstSession = sortedSubjectSessions[0]
            let materialGroups = Dictionary(grouping: sortedSubjectSessions, by: materialGroupingKey)
            let materialSummaries = materialGroups.map { _, materialSessions in
                DayStudyMaterialSummary.make(from: materialSessions)
            }
            .sorted { left, right in
                localizedMaterialName(left.materialName)
                    .localizedStandardCompare(localizedMaterialName(right.materialName)) == .orderedAscending
            }

            return DayStudySubjectSummary(
                id: "subject-\(firstSession.subjectId)-\(firstSession.subjectName)",
                subjectName: firstSession.subjectName.isEmpty ? "未設定" : firstSession.subjectName,
                totalMinutes: sortedSubjectSessions.reduce(0) { $0 + $1.durationMinutes },
                sessionCount: sortedSubjectSessions.count,
                materials: materialSummaries
            )
        }
        .sorted { left, right in
            localizedSubjectName(left.subjectName)
                .localizedStandardCompare(localizedSubjectName(right.subjectName)) == .orderedAscending
        }
    }

    private static func materialGroupingKey(_ session: StudySession) -> String {
        if let materialId = session.materialId {
            return "id-\(materialId)"
        }
        return "name-\(session.materialName)"
    }

    private static func localizedSubjectName(_ value: String) -> String {
        value == "未設定" ? "\u{10FFFF}" : value
    }

    private static func localizedMaterialName(_ value: String) -> String {
        value == "教材未設定" ? "\u{10FFFF}" : value
    }
}

struct DayStudyMaterialSummary: Identifiable, Hashable {
    var id: String
    var materialName: String
    var totalMinutes: Int
    var sessionCount: Int
    var sessions: [StudySession]
    var notes: [String]
    var intervals: [StudySessionInterval]
    var problemRecords: [ProblemSessionRecord]
    var wrongProblemCount: Int
    var reviewCorrectProblemCount: Int

    static func make(from sessions: [StudySession]) -> DayStudyMaterialSummary {
        let sortedSessions = sessions.sorted { $0.sessionStartTime < $1.sessionStartTime }
        let firstSession = sortedSessions[0]
        let notes = sortedSessions.compactMap { $0.note?.nilIfBlank }
        let problemRecords = sortedSessions
            .flatMap(\.problemRecords)
            .sorted { $0.number < $1.number }
        let wrongProblemCount = sortedSessions.reduce(0) { result, session in
            result + (session.effectiveWrongProblemCount ?? 0)
        }

        return DayStudyMaterialSummary(
            id: firstSession.materialId.map { "material-\($0)" } ?? "material-name-\(firstSession.materialName)",
            materialName: firstSession.materialName.isEmpty ? "教材未設定" : firstSession.materialName,
            totalMinutes: sortedSessions.reduce(0) { $0 + $1.durationMinutes },
            sessionCount: sortedSessions.count,
            sessions: sortedSessions,
            notes: notes,
            intervals: sortedSessions.flatMap(\.effectiveIntervals).sorted { $0.startTime < $1.startTime },
            problemRecords: problemRecords,
            wrongProblemCount: wrongProblemCount,
            reviewCorrectProblemCount: sortedSessions.reduce(0) { $0 + $1.effectiveReviewCorrectProblemCount }
        )
    }
}
