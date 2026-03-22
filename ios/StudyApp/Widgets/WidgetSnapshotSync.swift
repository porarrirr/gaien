import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WidgetSnapshotSync {
    private unowned let container: StudyAppContainer
    private var refreshTask: Task<Void, Never>?

    init(container: StudyAppContainer) {
        self.container = container
    }

    func scheduleRefresh(reason: String) {
        refreshTask?.cancel()
        refreshTask = Task {
            do {
                try await refresh(reason: reason)
            } catch is CancellationError {
                return
            } catch {
                container.logger.log(
                    category: .app,
                    level: .warning,
                    message: "Widget snapshot refresh failed",
                    details: "reason=\(reason)",
                    error: error
                )
            }
        }
    }

    private func refresh(reason: String) async throws {
        let snapshot = try await buildSnapshot()
        try StudyWidgetSnapshotStore.write(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        container.logger.log(
            category: .app,
            message: "Widget snapshot refreshed",
            details: "reason=\(reason)"
        )
    }

    private func buildSnapshot() async throws -> StudyWidgetSnapshot {
        let now = container.clock.now()
        let today = now.startOfDay
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: now)
        let weekStart = (weekInterval?.start ?? today).epochMilliseconds
        let weekEnd = (weekInterval?.end ?? tomorrow).epochMilliseconds

        async let sessionsTask = container.persistence.getAllSessions()
        async let dailyGoalTask = container.persistence.getActiveGoalByType(.daily)
        async let weeklyGoalTask = container.persistence.getActiveGoalByType(.weekly)
        async let examsTask = container.persistence.getUpcomingExams(now: now)

        let sessions = try await sessionsTask
        let dailyGoal = try await dailyGoalTask
        let weeklyGoal = try await weeklyGoalTask
        let exams = try await examsTask

        let todaySessions = sessions.filter { session in
            session.startTime >= today.epochMilliseconds && session.startTime < tomorrow.epochMilliseconds
        }
        let weeklySessions = sessions.filter { session in
            session.startTime >= weekStart && session.startTime < weekEnd
        }

        let studyDays = Set(sessions.map { Date(epochMilliseconds: $0.startTime).startOfDay.epochDay })
        let sortedStudyDays = studyDays.sorted()

        return StudyWidgetSnapshot(
            generatedAt: now.epochMilliseconds,
            todayStudyMinutes: todaySessions.reduce(0) { $0 + $1.durationMinutes },
            todaySessionCount: todaySessions.count,
            dailyGoalMinutes: dailyGoal?.targetMinutes,
            weeklyGoalMinutes: weeklyGoal?.targetMinutes,
            weeklyStudyMinutes: weeklySessions.reduce(0) { $0 + $1.durationMinutes },
            streakDays: streakDays(from: studyDays, referenceDay: today.epochDay),
            bestStreak: bestStreak(from: sortedStudyDays),
            upcomingExams: Array(exams.prefix(3)).map { exam in
                StudyWidgetExamSummary(
                    name: exam.name,
                    epochDay: exam.date,
                    daysRemaining: exam.daysRemaining(from: now)
                )
            },
            weekActivity: buildWeekActivity(from: sessions, referenceDate: today)
        )
    }

    private func buildWeekActivity(
        from sessions: [StudySession],
        referenceDate: Date
    ) -> [StudyWidgetActivitySummary] {
        let minutesByDay = Dictionary(grouping: sessions) { session in
            Date(epochMilliseconds: session.startTime).startOfDay.epochDay
        }
        .mapValues { daySessions in
            daySessions.reduce(0) { $0 + $1.durationMinutes }
        }

        return stride(from: 6, through: 0, by: -1).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate) else {
                return nil
            }
            return StudyWidgetActivitySummary(
                dayLabel: studyWidgetDayLabel(for: date),
                minutes: minutesByDay[date.epochDay] ?? 0,
                isToday: offset == 0
            )
        }
    }

    private func streakDays(from studyDays: Set<Int64>, referenceDay: Int64) -> Int {
        var streak = 0
        var currentDay = referenceDay
        while studyDays.contains(currentDay) {
            streak += 1
            currentDay -= 1
        }
        return streak
    }

    private func bestStreak(from sortedStudyDays: [Int64]) -> Int {
        guard var previous = sortedStudyDays.first else { return 0 }
        var best = 1
        var current = 1
        for day in sortedStudyDays.dropFirst() {
            if day - previous == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
            previous = day
        }
        return best
    }
}
