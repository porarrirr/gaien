import Foundation

struct Clock {
    func now() -> Date {
        Date()
    }

    func startOfToday(reference: Date = Date()) -> Int64 {
        Calendar.current.startOfDay(for: reference).epochMilliseconds
    }

    func startOfWeek(reference: Date = Date()) -> Int64 {
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: reference)
        return (interval?.start ?? Calendar.current.startOfDay(for: reference)).epochMilliseconds
    }
}

struct GetHomeDataUseCase {
    let studySessionRepository: StudySessionRepository
    let goalRepository: GoalRepository
    let examRepository: ExamRepository
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

        let todaySessions = try await todaySessionsTask
        let goals = try await goalsTask
        let weeklySessions = try await weeklySessionsTask
        let upcomingExams = try await upcomingExamsTask
        let todayGoal = goals.latestActiveDailyGoal(for: todayWeekday)
        let weeklyGoal = goals.latestActiveWeeklyGoal()

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
            upcomingExams: upcomingExams.sorted { $0.date < $1.date }
        )
    }
}

struct GetRecentMaterialsUseCase {
    let materialRepository: MaterialRepository
    let studySessionRepository: StudySessionRepository
    let subjectRepository: SubjectRepository

    func execute(limit: Int = 5) async throws -> [(Material, Subject)] {
        async let materialsTask = materialRepository.getAllMaterials()
        async let sessionsTask = studySessionRepository.getAllSessions()
        async let subjectsTask = subjectRepository.getAllSubjects()

        let materials = try await materialsTask
        let sessions = try await sessionsTask
        let subjects = try await subjectsTask

        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        let materialMap = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
        var orderedIds = [Int64]()
        for materialId in sortedSessions.compactMap(\.materialId) where !orderedIds.contains(materialId) {
            orderedIds.append(materialId)
            if orderedIds.count == limit {
                break
            }
        }
        return orderedIds.compactMap { materialId in
            guard let material = materialMap[materialId], let subject = subjectMap[material.subjectId] else { return nil }
            return (material, subject)
        }
    }
}

struct GetUpcomingExamsUseCase {
    let examRepository: ExamRepository
    let clock: Clock

    func execute(limit: Int? = nil) async throws -> [Exam] {
        let exams = try await examRepository.getUpcomingExams(now: clock.now())
        if let limit {
            return Array(exams.prefix(limit))
        }
        return exams
    }
}

struct ManageGoalsUseCase {
    let repository: GoalRepository

    func updateGoal(
        type: GoalType,
        targetMinutes: Int,
        dayOfWeek: StudyWeekday? = nil,
        weekStartDay: StudyWeekday = .monday
    ) async throws {
        let goals = try await repository.getAllGoals()
        switch type {
        case .daily:
            if let current = goals.first(where: {
                $0.type == .daily &&
                $0.isActive &&
                $0.deletedAt == nil &&
                $0.dayOfWeek == dayOfWeek
            }) {
                var updated = current
                updated.targetMinutes = targetMinutes
                updated.dayOfWeek = dayOfWeek
                updated.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(updated)
            } else {
                try await repository.insertGoal(
                    Goal(
                        type: .daily,
                        targetMinutes: targetMinutes,
                        dayOfWeek: dayOfWeek,
                        weekStartDay: weekStartDay,
                        isActive: true
                    )
                )
            }
        case .weekly:
            for goal in goals where goal.type == .weekly && goal.isActive && goal.deletedAt == nil {
                var inactive = goal
                inactive.isActive = false
                inactive.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(inactive)
            }

            if let current = goals.first(where: {
                $0.type == .weekly &&
                $0.isActive &&
                $0.deletedAt == nil
            }) {
                var updated = current
                updated.targetMinutes = targetMinutes
                updated.weekStartDay = weekStartDay
                updated.isActive = true
                updated.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(updated)
            } else {
                try await repository.insertGoal(
                    Goal(
                        type: .weekly,
                        targetMinutes: targetMinutes,
                        weekStartDay: weekStartDay,
                        isActive: true
                    )
                )
            }
        }
    }
}

struct SaveStudySessionUseCase {
    let sessionRepository: StudySessionRepository
    let subjectRepository: SubjectRepository
    let materialRepository: MaterialRepository

    func saveManualSession(subjectId: Int64, materialId: Int64?, startTime: Int64, endTime: Int64, note: String?) async throws {
        guard let subject = try await subjectRepository.getSubjectById(subjectId) else {
            throw ValidationError(message: "科目を選択してください")
        }
        let duration = endTime - startTime
        guard duration > 0 else {
            throw ValidationError(message: "終了時刻は開始時刻より後にしてください")
        }
        let materials = try await materialRepository.getAllMaterials()
        let material = materials.first(where: { $0.id == materialId })
        let materialName = material?.name ?? ""
        try await sessionRepository.insertSession(
            StudySession(
                materialId: materialId,
                materialSyncId: material?.syncId,
                materialName: materialName,
                subjectId: subject.id,
                subjectSyncId: subject.syncId,
                subjectName: subject.name,
                sessionType: .manual,
                startTime: startTime,
                endTime: endTime,
                intervals: [StudySessionInterval(startTime: startTime, endTime: endTime)],
                note: note?.nilIfBlank
            )
        )
    }
}

struct ManageMaterialsUseCase {
    let materialRepository: MaterialRepository
    let subjectRepository: SubjectRepository
    let bookSearchRepository: BookSearchRepository

    func searchBook(isbn: String) async throws -> BookInfo {
        try await bookSearchRepository.searchByIsbn(isbn)
    }

    func addMaterial(
        name: String,
        subjectId: Int64,
        totalPages: Int,
        color: Int? = nil,
        note: String? = nil
    ) async throws {
        guard let subject = try await subjectRepository.getSubjectById(subjectId) else {
            throw ValidationError(message: "科目を選択してください")
        }
        try await materialRepository.insertMaterial(
            Material(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                subjectId: subjectId,
                subjectSyncId: subject.syncId,
                totalPages: totalPages,
                currentPage: 0,
                color: color,
                note: note?.nilIfBlank
            )
        )
    }
}

struct ManagePlansUseCase {
    let repository: PlanRepository

    func createPlan(name: String, startDate: Date, endDate: Date, items: [PlanItem]) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError(message: "プラン名を入力してください")
        }
        guard startDate < endDate else {
            throw ValidationError(message: "開始日は終了日より前に設定してください")
        }
        guard !items.isEmpty else {
            throw ValidationError(message: "少なくとも1つの学習項目を追加してください")
        }
        try await repository.createPlan(
            StudyPlan(
                name: trimmed,
                startDate: Calendar.current.startOfDay(for: startDate).epochMilliseconds,
                endDate: Calendar.current.startOfDay(for: endDate).epochMilliseconds,
                isActive: true
            ),
            items: items
        )
    }
}

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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月"
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

struct ExportImportDataUseCase {
    let repository: AppDataRepository

    func exportJSON() async throws -> String {
        try await repository.exportJSON()
    }

    func exportCSV() async throws -> String {
        try await repository.exportCSV()
    }

    func importJSON(_ json: String, currentPreferences: AppPreferences) async throws -> AppPreferences {
        try await repository.importJSON(json, currentPreferences: currentPreferences)
    }
}

struct GetSettingsSummaryUseCase {
    let sessionRepository: StudySessionRepository

    func execute() async throws -> SettingsSummary {
        let sessions = try await sessionRepository.getAllSessions()
        return SettingsSummary(
            totalSessions: sessions.count,
            totalStudyMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }
        )
    }
}

struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
