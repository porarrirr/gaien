import Combine
import Foundation

@MainActor
final class HistoryViewModel: ScreenViewModel {
    @Published private(set) var sessions: [StudySession] = []
    @Published private(set) var subjects: [Subject] = []
    @Published var filterSubjectId: Int64?

    var filteredSessions: [StudySession] {
        guard let filterSubjectId else { return sessions }
        return sessions.filter { $0.subjectId == filterSubjectId }
    }

    func load() async {
        do {
            async let sessionsTask = app.persistence.getAllSessions()
            async let subjectsTask = app.persistence.getAllSubjects()
            sessions = try await sessionsTask
            subjects = try await subjectsTask
        } catch {
            app.present(error)
        }
    }

    func setFilter(_ subjectId: Int64?) {
        filterSubjectId = subjectId
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
