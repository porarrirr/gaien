import Foundation

struct GetReportsDataUseCase {
    let subjectRepository: SubjectRepository
    let sessionRepository: StudySessionRepository
    let clock: Clock

    func execute(reference: Date = Date()) async throws -> ReportsData {
        async let subjectsTask = subjectRepository.getAllSubjects()
        async let sessionsTask = sessionRepository.getAllSessions()
        let subjects = try await subjectsTask
        let sessions = try await sessionsTask

        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let daily = reportDailyData(subjects: subjects, sessions: sortedSessions, reference: reference)
        let weekly = reportWeeklyData(subjects: subjects, sessions: sortedSessions, reference: reference)
        let monthly = reportMonthlyData(sessions: sortedSessions, reference: reference)
        let bySubject = subjectBreakdown(subjects: subjects, sessions: sortedSessions, reference: reference)

        return ReportsData(
            daily: daily,
            weekly: weekly,
            monthly: monthly,
            bySubject: bySubject,
            ratingAverages: ratingAverages(sessions: sortedSessions, reference: reference),
            streakDays: streakDays(sessions: sortedSessions, reference: reference),
            bestStreak: bestStreak(sessions: sortedSessions)
        )
    }

    private func reportDailyData(subjects: [Subject], sessions: [StudySession], reference: Date) -> [DailyStudyData] {
        let formatter = StudyFormatters.shortDateWithWeekday
        return (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: reference) else { return nil }
            let start = Calendar.current.startOfDay(for: date).epochMilliseconds
            let end = start + 86_400_000
            let periodSessions = sessions.filter { $0.startTime >= start && $0.startTime < end }
            let segments = subjectSegments(subjects: subjects, sessions: periodSessions)
            let minutes = segments.reduce(0) { $0 + $1.minutes }
            return DailyStudyData(
                date: start,
                dateLabel: formatter.string(from: date),
                minutes: minutes,
                hours: Double(minutes) / 60,
                segments: segments
            )
        }
        .reversed()
    }

    private func reportWeeklyData(subjects: [Subject], sessions: [StudySession], reference: Date) -> [WeeklyStudyData] {
        let formatter = StudyFormatters.shortDate
        return (0..<4).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: reference) else { return nil }
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: date)
            let start = (interval?.start ?? date).epochMilliseconds
            let end = Int64((interval?.end ?? date).epochMilliseconds)
            let periodSessions = sessions.filter { $0.startTime >= start && $0.startTime < end }
            let segments = subjectSegments(subjects: subjects, sessions: periodSessions)
            let minutes = segments.reduce(0) { $0 + $1.minutes }
            return WeeklyStudyData(
                weekStart: start,
                weekLabel: "\(formatter.string(from: Date(epochMilliseconds: start)))週",
                hours: minutes / 60,
                minutes: minutes % 60,
                segments: segments
            )
        }
        .reversed()
    }

    private func subjectSegments(subjects: [Subject], sessions: [StudySession]) -> [SubjectStudySegment] {
        subjects.compactMap { subject in
            let minutes = sessions
                .filter { $0.subjectId == subject.id }
                .reduce(0) { $0 + $1.durationMinutes }
            guard minutes > 0 else { return nil }
            return SubjectStudySegment(
                subjectId: subject.id,
                subjectName: subject.name,
                minutes: minutes,
                color: subject.color
            )
        }
    }

    private func reportMonthlyData(sessions: [StudySession], reference: Date) -> [MonthlyStudyData] {
        let formatter = StudyFormatters.monthOnly
        return (0..<6).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .month, value: -offset, to: reference),
                  let interval = Calendar.current.dateInterval(of: .month, for: date) else {
                return nil
            }
            let minutes = sessions.filter {
                $0.startTime >= interval.start.epochMilliseconds && $0.startTime <= interval.end.epochMilliseconds
            }
            .reduce(0) { $0 + $1.durationMinutes }
            return MonthlyStudyData(
                monthStart: interval.start.epochMilliseconds,
                monthLabel: formatter.string(from: interval.start),
                totalHours: minutes / 60
            )
        }
        .reversed()
    }

    private func subjectBreakdown(subjects: [Subject], sessions: [StudySession], reference: Date) -> [SubjectStudyData] {
        guard let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: reference) else { return [] }
        let lowerBound = monthAgo.epochMilliseconds
        return subjects.compactMap { subject in
            let totalMinutes = sessions
                .filter { $0.subjectId == subject.id && $0.startTime >= lowerBound && $0.startTime <= reference.epochMilliseconds }
                .reduce(0) { $0 + $1.durationMinutes }
            guard totalMinutes > 0 else { return nil }
            return SubjectStudyData(
                subjectName: subject.name,
                hours: totalMinutes / 60,
                minutes: totalMinutes % 60,
                color: subject.color
            )
        }
        .sorted { ($0.hours * 60 + $0.minutes) > ($1.hours * 60 + $1.minutes) }
    }

    private func ratingAverages(sessions: [StudySession], reference: Date) -> RatingAveragesData {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: reference)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? reference
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: reference)
        let monthInterval = calendar.dateInterval(of: .month, for: reference)

        return RatingAveragesData(
            today: weightedAverageRating(
                sessions: sessions,
                start: todayStart.epochMilliseconds,
                end: todayEnd.epochMilliseconds
            ),
            week: weightedAverageRating(
                sessions: sessions,
                start: (weekInterval?.start ?? todayStart).epochMilliseconds,
                end: (weekInterval?.end ?? todayEnd).epochMilliseconds
            ),
            month: weightedAverageRating(
                sessions: sessions,
                start: (monthInterval?.start ?? todayStart).epochMilliseconds,
                end: (monthInterval?.end ?? todayEnd).epochMilliseconds
            )
        )
    }

    private func weightedAverageRating(sessions: [StudySession], start: Int64, end: Int64) -> RatingAverageSummary {
        let ratedSessions = sessions.filter {
            $0.startTime >= start &&
            $0.startTime < end &&
            $0.rating != nil
        }

        let ratedDuration = ratedSessions.reduce(Int64(0)) { $0 + $1.duration }
        guard ratedDuration > 0 else {
            return RatingAverageSummary(average: nil, ratedMinutes: 0)
        }

        let weightedTotal = ratedSessions.reduce(0.0) { partial, session in
            partial + (Double(session.rating ?? 0) * Double(session.duration))
        }

        return RatingAverageSummary(
            average: weightedTotal / Double(ratedDuration),
            ratedMinutes: Int(ratedDuration / 60_000)
        )
    }

    private func streakDays(sessions: [StudySession], reference: Date) -> Int {
        let days = Set(sessions.map { Date(epochMilliseconds: $0.startTime).startOfDay.epochDay })
        var streak = 0
        var current = reference.startOfDay
        for index in 0..<365 {
            if days.contains(current.epochDay) {
                streak += 1
            } else if index > 0 {
                break
            }
            current = Calendar.current.date(byAdding: .day, value: -1, to: current) ?? current
        }
        return streak
    }

    private func bestStreak(sessions: [StudySession]) -> Int {
        let sortedDays = Set(sessions.map { Date(epochMilliseconds: $0.startTime).startOfDay.epochDay }).sorted()
        guard var previous = sortedDays.first else { return 0 }
        var current = 1
        var best = 1
        for day in sortedDays.dropFirst() {
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
