import Combine
import Foundation

@MainActor
final class MaterialHistoryViewModel: ScreenViewModel {
    @Published private(set) var material: Material?
    @Published private(set) var subject: Subject?
    @Published private(set) var sessions: [StudySession] = []
    @Published var displayedMonth = Calendar.current.startOfDay(for: Date())
    @Published var selectedDate = Calendar.current.startOfDay(for: Date())

    let materialId: Int64

    init(app: StudyAppContainer, materialId: Int64) {
        self.materialId = materialId
        super.init(app: app)
    }

    var latestStudyDate: Date? {
        sessions.max(by: { $0.sessionStartTime < $1.sessionStartTime })?.startDate.startOfDay
    }

    var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var studyMinutesByDay: [Int: Int] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [:] }
        return sessions
            .filter { session in
                session.startDate >= interval.start && session.startDate < interval.end
            }
            .reduce(into: [:]) { result, session in
                let day = calendar.component(.day, from: session.startDate)
                result[day, default: 0] += session.durationMinutes
            }
    }

    var selectedDateSessions: [StudySession] {
        sessions
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.sessionStartTime < $1.sessionStartTime }
    }

    var selectedDateMinutes: Int {
        selectedDateSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    func load() async {
        do {
            async let materialsTask = app.persistence.getAllMaterials()
            async let subjectsTask = app.persistence.getAllSubjects()
            async let sessionsTask = app.persistence.getAllSessions()

            let materials = try await materialsTask
            let subjects = try await subjectsTask
            let allSessions = try await sessionsTask

            material = materials.first { $0.id == materialId }
            subject = material.flatMap { selectedMaterial in
                subjects.first { $0.id == selectedMaterial.subjectId }
            }
            sessions = allSessions
                .filter { $0.materialId == materialId }
                .sorted { $0.sessionStartTime > $1.sessionStartTime }

            let initialDate = latestStudyDate ?? Date().startOfDay
            selectedDate = initialDate
            displayedMonth = initialDate
        } catch {
            app.present(error)
        }
    }

    func previousMonth() {
        moveMonth(by: -1)
    }

    func nextMonth() {
        moveMonth(by: 1)
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        displayedMonth = selectedDate
    }

    private func moveMonth(by value: Int) {
        let calendar = Calendar.current
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth),
              let monthInterval = calendar.dateInterval(of: .month, for: newMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: newMonth) else {
            return
        }
        let currentDay = calendar.component(.day, from: selectedDate)
        let clampedDay = min(currentDay, dayRange.count)
        selectedDate = calendar.date(byAdding: .day, value: clampedDay - 1, to: monthInterval.start) ?? monthInterval.start
        displayedMonth = selectedDate
    }
}
