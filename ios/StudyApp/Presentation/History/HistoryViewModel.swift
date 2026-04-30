import Combine
import Foundation

@MainActor
final class HistoryViewModel: ScreenViewModel {
    @Published private(set) var sessions: [StudySession] = []
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var materials: [Material] = []
    @Published var filterSubjectId: Int64?

    var filteredSessions: [StudySession] {
        guard let filterSubjectId else { return sessions }
        return sessions.filter { $0.subjectId == filterSubjectId }
    }

    func load() async {
        do {
            async let sessionsTask = app.persistence.getAllSessions()
            async let subjectsTask = app.persistence.getAllSubjects()
            async let materialsTask = app.persistence.getAllMaterials()
            sessions = try await sessionsTask
            subjects = try await subjectsTask
            materials = try await materialsTask
        } catch {
            app.present(error)
        }
    }

    func setFilter(_ subjectId: Int64?) {
        filterSubjectId = subjectId
    }

    func materialProblemChapters(for session: StudySession) -> [ProblemChapter] {
        guard let materialId = session.materialId else { return [] }
        return materials.first(where: { $0.id == materialId })?.problemChapters ?? []
    }

    func materialProblemCount(for session: StudySession) -> Int {
        guard let materialId = session.materialId else { return 0 }
        return materials.first(where: { $0.id == materialId })?.effectiveTotalProblems ?? 0
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
}
