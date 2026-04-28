import Combine
import Foundation

@MainActor
final class CalendarViewModel: ScreenViewModel {
    @Published private(set) var monthStudyMap: [Int: Int] = [:]
    @Published private(set) var daySessionsMap: [Int: [StudySession]] = [:]
    @Published private(set) var materials: [Material] = []
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
            let sessions = try await sessionsTask
            materials = try await materialsTask
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

    func materialProblemCount(for session: StudySession) -> Int {
        guard let materialId = session.materialId else { return 0 }
        return materials.first(where: { $0.id == materialId })?.totalProblems ?? 0
    }

    func updateSession(
        _ session: StudySession,
        durationMinutes: Int,
        note: String?,
        rating: Int?,
        problemStart: Int? = nil,
        problemEnd: Int? = nil,
        wrongProblemCount: Int? = nil,
        problemRecords: [ProblemSessionRecord] = []
    ) {
        perform {
            guard durationMinutes > 0 else { throw ValidationError(message: "学習時間は0より大きくしてください") }
            var updated = session
            updated.endTime = updated.startTime + Int64(durationMinutes * 60_000)
            updated.intervals = [StudySessionInterval(startTime: updated.startTime, endTime: updated.endTime)]
            updated.note = note?.nilIfBlank
            updated.rating = rating
            updated.problemStart = problemStart
            updated.problemEnd = problemEnd
            updated.wrongProblemCount = wrongProblemCount
            updated.problemRecords = problemRecords
            try await self.app.persistence.updateSession(updated)
            if let materialId = updated.materialId {
                let affectedNumbers = Set(session.problemRecords.map(\.number))
                    .union(problemRecords.map(\.number))
                _ = try await self.app.persistence.reconcileMaterialProblemRecords(
                    materialId: materialId,
                    affectedNumbers: affectedNumbers
                )
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteSession(_ session: StudySession) {
        perform {
            try await self.app.persistence.deleteSession(session)
            if let materialId = session.materialId {
                _ = try await self.app.persistence.reconcileMaterialProblemRecords(
                    materialId: materialId,
                    affectedNumbers: Set(session.problemRecords.map(\.number))
                )
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }
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
