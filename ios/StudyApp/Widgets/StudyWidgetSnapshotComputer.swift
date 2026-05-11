import Foundation

/// Pure, testable compute layer for the widget snapshot. Sits in-between the
/// repository-fetching `WidgetSnapshotSync` (which still runs on the main
/// actor because the repository is `@MainActor`) and the serialized
/// `StudyWidgetSnapshot` that the widget extension consumes.
///
/// Widget updates previously pulled *all* sessions and computed streaks over
/// the entire history on the main actor. This struct keeps the computation
/// pure (no clock / no main actor) so we can:
///   1. Unit-test it without Core Data, and
///   2. Call it off the main actor from `Task.detached` once we have the
///      bounded recent-sessions + study-day-counts inputs.
struct StudyWidgetSnapshotComputer {

    struct Inputs {
        /// Sessions recent enough to contribute to today/week totals. Must
        /// include the current week and today at minimum. `WidgetSnapshotSync`
        /// uses a 7-day lookback.
        var recentSessions: [StudySession]
        /// All goals (there are few, so we can load them fully).
        var goals: [Goal]
        /// Upcoming exams to surface at the top of the widget.
        var upcomingExams: [Exam]
        /// Epoch-day list (distinct) of every day the user has ever studied.
        /// Used for streak/best-streak computation. Loading this as a bounded
        /// `Set` is much cheaper than pulling every session.
        var studyDayEpochDays: [Int64]
        /// The reference point for "today", so tests can inject a fixed date.
        var referenceDate: Date
        /// Explicit calendar so tests aren't at the mercy of the device locale.
        var calendar: Calendar

        init(
            recentSessions: [StudySession],
            goals: [Goal],
            upcomingExams: [Exam],
            studyDayEpochDays: [Int64],
            referenceDate: Date,
            calendar: Calendar = .current
        ) {
            self.recentSessions = recentSessions
            self.goals = goals
            self.upcomingExams = upcomingExams
            self.studyDayEpochDays = studyDayEpochDays
            self.referenceDate = referenceDate
            self.calendar = calendar
        }
    }

    static func compute(_ inputs: Inputs) -> StudyWidgetSnapshot {
        let calendar = inputs.calendar
        let now = inputs.referenceDate
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekStart = (weekInterval?.start ?? today).epochMilliseconds
        let weekEnd = (weekInterval?.end ?? tomorrow).epochMilliseconds
        let todayWeekday = StudyWeekday.from(calendarWeekday: calendar.component(.weekday, from: now))

        let dailyGoal = inputs.goals.latestActiveDailyGoal(for: todayWeekday)
        let weeklyGoal = inputs.goals.latestActiveWeeklyGoal()

        let todayStartMs = today.epochMilliseconds
        let tomorrowMs = tomorrow.epochMilliseconds
        let todaySessions = inputs.recentSessions.filter { session in
            session.startTime >= todayStartMs && session.startTime < tomorrowMs
        }
        let weeklySessions = inputs.recentSessions.filter { session in
            session.startTime >= weekStart && session.startTime < weekEnd
        }

        let studyDaysSet = Set(inputs.studyDayEpochDays)
        let sortedStudyDays = inputs.studyDayEpochDays.sorted()

        return StudyWidgetSnapshot(
            generatedAt: now.epochMilliseconds,
            todayStudyMinutes: todaySessions.reduce(0) { $0 + $1.durationMinutes },
            todaySessionCount: todaySessions.count,
            dailyGoalMinutes: dailyGoal?.targetMinutes,
            weeklyGoalMinutes: weeklyGoal?.targetMinutes,
            weeklyStudyMinutes: weeklySessions.reduce(0) { $0 + $1.durationMinutes },
            streakDays: streakDays(from: studyDaysSet, referenceDay: today.epochDay),
            bestStreak: bestStreak(from: sortedStudyDays),
            upcomingExams: Array(inputs.upcomingExams.prefix(3)).map { exam in
                StudyWidgetExamSummary(
                    name: exam.name,
                    epochDay: exam.date,
                    daysRemaining: exam.daysRemaining(from: now)
                )
            },
            weekActivity: buildWeekActivity(
                from: inputs.recentSessions,
                referenceDate: today,
                calendar: calendar
            )
        )
    }

    // MARK: - Helpers

    static func buildWeekActivity(
        from sessions: [StudySession],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [StudyWidgetActivitySummary] {
        let minutesByDay = Dictionary(grouping: sessions) { session in
            Date(epochMilliseconds: session.startTime).startOfDay.epochDay
        }
        .mapValues { daySessions in
            daySessions.reduce(0) { $0 + $1.durationMinutes }
        }

        return stride(from: 6, through: 0, by: -1).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate) else {
                return nil
            }
            return StudyWidgetActivitySummary(
                dayLabel: studyWidgetDayLabel(for: date),
                minutes: minutesByDay[date.epochDay] ?? 0,
                isToday: offset == 0
            )
        }
    }

    static func streakDays(from studyDays: Set<Int64>, referenceDay: Int64) -> Int {
        var streak = 0
        var currentDay = referenceDay
        while studyDays.contains(currentDay) {
            streak += 1
            currentDay -= 1
        }
        return streak
    }

    static func bestStreak(from sortedStudyDays: [Int64]) -> Int {
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
