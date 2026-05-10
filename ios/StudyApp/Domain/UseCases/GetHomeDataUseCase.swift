import Foundation

struct GetHomeDataUseCase {
    let studySessionRepository: StudySessionRepository
    let goalRepository: GoalRepository
    let examRepository: ExamRepository
    let timetableRepository: TimetableRepository
    let problemReviewRepository: ProblemReviewRepository
    let clock: Clock

    func execute() async throws -> HomeData {
        let todayStart = clock.startOfToday()
        let weekStart = clock.startOfWeek()
        let todayWeekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: clock.now()))
        let dayMs: Int64 = 86_400_000
        let weekMs = dayMs * 7

        async let todaySessionsTask = studySessionRepository.getSessionsBetweenDates(start: todayStart, end: todayStart + dayMs)
        async let goalsTask = goalRepository.getAllGoals()
        async let weeklySessionsTask = studySessionRepository.getSessionsBetweenDates(start: weekStart, end: weekStart + weekMs)
        async let upcomingExamsTask = examRepository.getUpcomingExams(now: clock.now())
        async let timetablePeriodsTask = timetableRepository.getAllTimetablePeriods()
        async let timetableEntriesTask = timetableRepository.getAllTimetableEntries()
        async let timetableTermsTask = timetableRepository.getAllTimetableTerms()
        async let todayReviewProblemsTask = problemReviewRepository.getTodayReviewProblems(reference: clock.now())

        let todaySessions = try await todaySessionsTask
        let goals = try await goalsTask
        let weeklySessions = try await weeklySessionsTask
        let upcomingExams = try await upcomingExamsTask
        let timetablePeriods = try await timetablePeriodsTask
        let timetableEntries = try await timetableEntriesTask
        let timetableTerms = try await timetableTermsTask
        let todayReviewProblems = try await todayReviewProblemsTask
        let todayGoal = goals.latestActiveDailyGoal(for: todayWeekday)
        let weeklyGoal = goals.latestActiveWeeklyGoal()

        let timetableLessons = nextTimetableLessons(
            periods: timetablePeriods,
            entries: timetableEntries,
            terms: timetableTerms,
            reference: clock.now()
        )
        let currentLesson = timetableLessons.first { $0.isCurrent }
        let upcomingLesson = timetableLessons.first { !$0.isCurrent }

        return HomeData(
            todayStudyMinutes: todaySessions.reduce(0) { $0 + $1.durationMinutes },
            todaySessions: todaySessions
                .sorted { $0.startTime > $1.startTime }
                .map {
                    TodaySession(
                        id: $0.id,
                        subjectName: $0.subjectName,
                        materialName: $0.materialName,
                        duration: $0.duration,
                        startTime: $0.startTime
                    )
            },
            todayGoal: todayGoal,
            weeklyGoal: weeklyGoal,
            weeklyStudyMinutes: weeklySessions.reduce(0) { $0 + $1.durationMinutes },
            upcomingExams: upcomingExams.sorted { $0.date < $1.date },
            timetableLesson: currentLesson,
            upcomingTimetableLesson: upcomingLesson,
            todayReviewProblems: todayReviewProblems
        )
    }

    private func nextTimetableLessons(
        periods: [TimetablePeriod],
        entries: [TimetableEntry],
        terms: [TimetableTerm],
        reference: Date
    ) -> [TimetableLesson] {
        let activePeriods = periods
            .filter { $0.isActive && $0.deletedAt == nil && $0.startMinute < $0.endMinute }
            .sorted { $0.sortOrder == $1.sortOrder ? $0.startMinute < $1.startMinute : $0.sortOrder < $1.sortOrder }
        guard !activePeriods.isEmpty else { return [] }

        let periodMap = Dictionary(uniqueKeysWithValues: activePeriods.map { ($0.id, $0) })
        let activeTerm = terms.first(where: { $0.deletedAt == nil && $0.isActive && $0.contains(reference) })
            ?? terms.filter { $0.deletedAt == nil && $0.isActive }.sorted { $0.endDate > $1.endDate }.first
        let referenceDay = reference.startOfDay.epochDay
        let activeEntries = entries.filter {
            $0.deletedAt == nil &&
            ($0.termId == activeTerm?.id || $0.termId == nil) &&
            ($0.validFromDate.map { referenceDay >= $0 } ?? true) &&
            ($0.validToDate.map { referenceDay <= $0 } ?? true) &&
            StudyWeekday.timetableDays.contains($0.dayOfWeek) &&
            periodMap[$0.periodId] != nil
        }
        guard !activeEntries.isEmpty else { return [] }

        let calendar = Calendar.current
        let currentMinutes = (calendar.component(.hour, from: reference) * 60) + calendar.component(.minute, from: reference)
        let referenceWeekday = StudyWeekday.from(calendarWeekday: calendar.component(.weekday, from: reference))
        var lessons: [TimetableLesson] = []

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: reference) else { continue }
            let day = StudyWeekday.from(calendarWeekday: calendar.component(.weekday, from: date))
            guard StudyWeekday.timetableDays.contains(day) else { continue }

            let dayEntries = activeEntries
                .filter { $0.dayOfWeek == day }
                .compactMap { entry -> (TimetableEntry, TimetablePeriod)? in
                    guard let period = periodMap[entry.periodId] else { return nil }
                    return (entry, period)
                }
                .sorted { $0.1.startMinute < $1.1.startMinute }

            for pair in dayEntries {
                let entry = pair.0
                let period = pair.1
                if offset == 0, day == referenceWeekday {
                    if currentMinutes >= period.startMinute && currentMinutes < period.endMinute {
                        lessons.append(TimetableLesson(entry: entry, period: period, dayOfWeek: day, date: date, isCurrent: true))
                        continue
                    }
                    if currentMinutes >= period.endMinute {
                        continue
                    }
                }
                lessons.append(TimetableLesson(entry: entry, period: period, dayOfWeek: day, date: date, isCurrent: false))
                if lessons.contains(where: { $0.isCurrent }) && lessons.contains(where: { !$0.isCurrent }) {
                    return lessons
                }
                if !lessons.contains(where: { $0.isCurrent }) && lessons.count >= 1 {
                    return lessons
                }
            }
        }

        return lessons
    }
}
