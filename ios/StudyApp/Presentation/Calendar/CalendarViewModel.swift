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
