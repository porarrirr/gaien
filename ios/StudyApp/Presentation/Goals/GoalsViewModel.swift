import Combine
import Foundation

@MainActor
final class GoalsViewModel: ScreenViewModel {
    @Published private(set) var dailyGoals: [StudyWeekday: Goal] = [:]
    @Published private(set) var weeklyGoal: Goal?
    @Published private(set) var todayWeekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: Date()))
    @Published private(set) var todayStudyMinutes = 0
    @Published private(set) var weeklyStudyMinutes = 0

    func load() async {
        do {
            let todayStart = app.clock.startOfToday()
            let weekStart = app.clock.startOfWeek()
            let dayMs: Int64 = 86_400_000
            let weekMs = dayMs * 7

            async let goalsTask = app.persistence.getAllGoals()
            async let todaySessionsTask = app.persistence.getSessionsBetweenDates(start: todayStart, end: todayStart + dayMs)
            async let weeklySessionsTask = app.persistence.getSessionsBetweenDates(start: weekStart, end: weekStart + weekMs)

            let goals = try await goalsTask
            let todaySessions = try await todaySessionsTask
            let weeklySessions = try await weeklySessionsTask

            dailyGoals = goals.latestActiveDailyGoalsByWeekday()
            weeklyGoal = goals.latestActiveWeeklyGoal()
            todayWeekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: Date()))
            todayStudyMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
            weeklyStudyMinutes = weeklySessions.reduce(0) { $0 + $1.durationMinutes }
        } catch {
            app.present(error)
        }
    }

    func updateDailyGoal(dayOfWeek: StudyWeekday, targetMinutes: Int) {
        perform {
            guard targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            let useCase = ManageGoalsUseCase(repository: self.app.persistence)
            try await useCase.updateGoal(type: .daily, targetMinutes: targetMinutes, dayOfWeek: dayOfWeek)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func updateWeeklyGoal(targetMinutes: Int) {
        perform {
            guard targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            let useCase = ManageGoalsUseCase(repository: self.app.persistence)
            try await useCase.updateGoal(type: .weekly, targetMinutes: targetMinutes)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}
