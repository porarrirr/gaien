import Foundation

enum SubjectIcon: String, CaseIterable, Codable, Identifiable, Hashable {
    case book = "BOOK"
    case calculator = "CALCULATOR"
    case flask = "FLASK"
    case globe = "GLOBE"
    case palette = "PALETTE"
    case music = "MUSIC"
    case code = "CODE"
    case atom = "ATOM"
    case dna = "DNA"
    case brain = "BRAIN"
    case language = "LANGUAGE"
    case history = "HISTORY"
    case other = "OTHER"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .book: return "book.closed.fill"
        case .calculator: return "function"
        case .flask: return "testtube.2"
        case .globe: return "globe.asia.australia.fill"
        case .palette: return "paintpalette.fill"
        case .music: return "music.note"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .atom: return "atom"
        case .dna: return "cross.case.fill"
        case .brain: return "brain.head.profile"
        case .language: return "character.book.closed.fill"
        case .history: return "clock.arrow.circlepath"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

enum GoalType: String, CaseIterable, Codable, Identifiable, Hashable {
    case daily = "DAILY"
    case weekly = "WEEKLY"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "1日の目標"
        case .weekly: return "週間目標"
        }
    }
}

enum StudyWeekday: String, CaseIterable, Codable, Identifiable, Hashable {
    case monday = "MONDAY"
    case tuesday = "TUESDAY"
    case wednesday = "WEDNESDAY"
    case thursday = "THURSDAY"
    case friday = "FRIDAY"
    case saturday = "SATURDAY"
    case sunday = "SUNDAY"

    var id: String { rawValue }

    var japaneseShortTitle: String {
        switch self {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }

    var japaneseTitle: String {
        japaneseShortTitle + "曜日"
    }

    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static func from(calendarWeekday: Int) -> StudyWeekday {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
        }
    }
}

enum ThemeMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "ライト"
        case .dark: return "ダーク"
        case .system: return "システム"
        }
    }

}

enum ColorTheme: String, CaseIterable, Codable, Identifiable, Hashable {
    case green
    case blue
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green: return "グリーン"
        case .blue: return "ブルー"
        case .orange: return "オレンジ"
        }
    }

    var hex: Int {
        switch self {
        case .green: return 0x4CAF50
        case .blue: return 0x2196F3
        case .orange: return 0xFF9800
        }
    }

    var accentHex: Int {
        switch self {
        case .green: return 0x2196F3
        case .blue: return 0x4CAF50
        case .orange: return 0x2196F3
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }
}

struct Subject: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var color: Int
    var icon: SubjectIcon?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?
}

struct Material: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var subjectId: Int64
    var subjectSyncId: String?
    var totalPages: Int = 0
    var currentPage: Int = 0
    var color: Int?
    var note: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(max(Double(currentPage) / Double(totalPages), 0), 1)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }
}

struct StudySession: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var materialId: Int64?
    var materialSyncId: String?
    var materialName: String = ""
    var subjectId: Int64
    var subjectSyncId: String?
    var subjectName: String = ""
    var startTime: Int64
    var endTime: Int64
    var note: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var duration: Int64 {
        max(endTime - startTime, 0)
    }

    var date: Int64 {
        Date(epochMilliseconds: startTime).epochDay
    }

    var durationMinutes: Int {
        Int(duration / 60_000)
    }

    var durationHours: Double {
        Double(duration) / 3_600_000
    }

    var durationFormatted: String {
        let totalSeconds = Int(duration / 1_000)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var durationJapaneseText: String {
        Goal.format(minutes: durationMinutes)
    }

    var startDate: Date {
        Date(epochMilliseconds: startTime)
    }

    var endDate: Date {
        Date(epochMilliseconds: endTime)
    }

    var dayOfWeek: StudyWeekday {
        StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: startDate))
    }
}

struct Goal: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var type: GoalType
    var targetMinutes: Int
    var weekStartDay: StudyWeekday = .monday
    var isActive: Bool = true
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var targetFormatted: String {
        Goal.format(minutes: targetMinutes)
    }

    static func format(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 {
            return "\(hours)時間\(remainder)分"
        }
        if hours > 0 {
            return "\(hours)時間"
        }
        return "\(remainder)分"
    }
}

struct Exam: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var date: Int64
    var note: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var dateValue: Date {
        Date(epochDay: date)
    }

    func daysRemaining(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: dateValue)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func isPast(from referenceDate: Date = Date()) -> Bool {
        daysRemaining(from: referenceDate) < 0
    }
}

struct StudyPlan: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var startDate: Int64
    var endDate: Int64
    var isActive: Bool
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var startDateValue: Date {
        Date(epochMilliseconds: startDate)
    }

    var endDateValue: Date {
        Date(epochMilliseconds: endDate)
    }
}

struct PlanItem: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var planId: Int64
    var planSyncId: String?
    var subjectId: Int64
    var subjectSyncId: String?
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int = 0
    var timeSlot: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?
}

struct MaterialWithSubject: Hashable {
    var material: Material
    var subjectName: String
}

struct PlanItemWithSubject: Identifiable, Hashable {
    var id: Int64 { item.id }
    var item: PlanItem
    var subject: Subject
}

struct DailyPlanSummary: Hashable {
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int

    var completionRate: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(Double(actualMinutes) / Double(targetMinutes), 1)
    }
}

struct WeeklyPlanSummary: Hashable {
    var weekStart: Int64
    var weekEnd: Int64
    var totalTargetMinutes: Int
    var totalActualMinutes: Int
    var dailyBreakdown: [StudyWeekday: DailyPlanSummary]
}

struct DailyStudyData: Identifiable, Hashable {
    var id: Int64 { date }
    var date: Int64
    var dateLabel: String
    var minutes: Int
    var hours: Double
}

struct WeeklyStudyData: Identifiable, Hashable {
    var id: Int64 { weekStart }
    var weekStart: Int64
    var weekLabel: String
    var hours: Int
    var minutes: Int
}

struct MonthlyStudyData: Identifiable, Hashable {
    var id: Int64 { monthStart }
    var monthStart: Int64
    var monthLabel: String
    var totalHours: Int
}

struct SubjectStudyData: Identifiable, Hashable {
    var id: String { subjectName }
    var subjectName: String
    var hours: Int
    var minutes: Int
    var color: Int
}

struct BookInfo: Codable, Hashable, Sendable {
    var title: String
    var authors: [String]
    var publisher: String?
    var publishedDate: String?
    var pageCount: Int?
    var thumbnailURL: String?
}

struct TimerSnapshot: Codable, Equatable {
    var subjectId: Int64
    var materialId: Int64?
    var startedAt: Int64?
    var accumulatedMilliseconds: Int64
    var isRunning: Bool

    func elapsedTime(at now: Date = Date()) -> Int64 {
        if isRunning, let startedAt {
            return accumulatedMilliseconds + max(now.epochMilliseconds - startedAt, 0)
        }
        return accumulatedMilliseconds
    }
}

struct AppPreferences: Codable, Equatable {
    var onboardingCompleted = false
    var reminderEnabled = false
    var reminderHour = 19
    var reminderMinute = 0
    var selectedColorTheme: ColorTheme = .green
    var selectedThemeMode: ThemeMode = .system
    var activeTimer: TimerSnapshot?
}

struct AuthSession: Codable, Equatable {
    var localId: String
    var email: String
    var idToken: String
    var refreshToken: String
}

struct SyncStatus: Equatable {
    var isAuthenticated = false
    var email: String?
    var isSyncing = false
    var lastSyncAt: Int64?
    var errorMessage: String?
}

struct HomeData: Hashable {
    var todayStudyMinutes: Int
    var todaySessions: [TodaySession]
    var weeklyGoal: Goal?
    var weeklyStudyMinutes: Int
    var upcomingExams: [Exam]
}

struct TodaySession: Identifiable, Hashable {
    var id: Int64
    var subjectName: String
    var materialName: String
    var duration: Int64
    var startTime: Int64
}

struct ReportsData: Hashable {
    var daily: [DailyStudyData]
    var weekly: [WeeklyStudyData]
    var monthly: [MonthlyStudyData]
    var bySubject: [SubjectStudyData]
    var streakDays: Int
    var bestStreak: Int
}

struct SettingsSummary: Hashable {
    var totalSessions: Int
    var totalStudyMinutes: Int
}

struct PlanData: Codable, Hashable {
    var plan: StudyPlan
    var items: [PlanItem]
}

struct AppData: Codable, Hashable {
    var subjects: [Subject]
    var materials: [Material]
    var sessions: [StudySession]
    var goals: [Goal]
    var exams: [Exam]
    var plans: [PlanData]
    var exportDate: Int64
}

protocol SubjectRepository {
    func getAllSubjects() async throws -> [Subject]
    func getSubjectById(_ id: Int64) async throws -> Subject?
    func insertSubject(_ subject: Subject) async throws -> Int64
    func updateSubject(_ subject: Subject) async throws
    func deleteSubject(_ subject: Subject) async throws
}

protocol MaterialRepository {
    func getAllMaterials() async throws -> [Material]
    func getMaterialsBySubjectId(_ subjectId: Int64) async throws -> [Material]
    func insertMaterial(_ material: Material) async throws -> Int64
    func updateMaterial(_ material: Material) async throws
    func deleteMaterial(_ material: Material) async throws
}

protocol StudySessionRepository {
    func getAllSessions() async throws -> [StudySession]
    func getSessionsBetweenDates(start: Int64, end: Int64) async throws -> [StudySession]
    func insertSession(_ session: StudySession) async throws -> Int64
    func updateSession(_ session: StudySession) async throws
    func deleteSession(_ session: StudySession) async throws
}

protocol GoalRepository {
    func getAllGoals() async throws -> [Goal]
    func getActiveGoalByType(_ type: GoalType) async throws -> Goal?
    func insertGoal(_ goal: Goal) async throws -> Int64
    func updateGoal(_ goal: Goal) async throws
    func deleteGoal(_ goal: Goal) async throws
}

protocol ExamRepository {
    func getAllExams() async throws -> [Exam]
    func getUpcomingExams(now: Date) async throws -> [Exam]
    func insertExam(_ exam: Exam) async throws -> Int64
    func updateExam(_ exam: Exam) async throws
    func deleteExam(_ exam: Exam) async throws
}

protocol PlanRepository {
    func getAllPlans() async throws -> [StudyPlan]
    func getPlanItems(planId: Int64) async throws -> [PlanItem]
    func createPlan(_ plan: StudyPlan, items: [PlanItem]) async throws -> Int64
    func insertPlanItem(_ item: PlanItem) async throws -> Int64
    func updatePlanItem(_ item: PlanItem) async throws
    func deletePlanItem(_ item: PlanItem) async throws
    func deletePlan(_ plan: StudyPlan) async throws
}

protocol AppPreferencesRepository {
    func loadPreferences() -> AppPreferences
    func savePreferences(_ preferences: AppPreferences)
}

protocol BookSearchRepository {
    func searchByIsbn(_ isbn: String) async throws -> BookInfo
}

protocol AppDataRepository {
    func exportData() async throws -> AppData
    func exportJSON() async throws -> String
    func exportCSV() async throws -> String
    func importJSON(_ json: String, currentPreferences: AppPreferences) async throws -> AppPreferences
    func deleteAllData() async throws
    func migrateLegacySnapshotIfNeeded(preferencesRepository: AppPreferencesRepository) async throws
}

@MainActor
protocol AuthRepository {
    var session: AuthSession? { get }
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() async throws
}

@MainActor
protocol SyncRepository {
    var status: SyncStatus { get }
    func syncNow() async throws
    func importLocalDataToCloud() async throws
}

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
        let dayMs: Int64 = 86_400_000
        let weekMs = dayMs * 7

        async let todaySessionsTask = studySessionRepository.getSessionsBetweenDates(start: todayStart, end: todayStart + dayMs)
        async let weeklyGoalTask = goalRepository.getActiveGoalByType(.weekly)
        async let weeklySessionsTask = studySessionRepository.getSessionsBetweenDates(start: weekStart, end: weekStart + weekMs)
        async let upcomingExamsTask = examRepository.getUpcomingExams(now: clock.now())

        let todaySessions = try await todaySessionsTask
        let weeklyGoal = try await weeklyGoalTask
        let weeklySessions = try await weeklySessionsTask
        let upcomingExams = try await upcomingExamsTask

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

    func updateGoal(type: GoalType, targetMinutes: Int, weekStartDay: StudyWeekday = .monday) async throws {
        let goals = try await repository.getAllGoals()
        for goal in goals where goal.type == type && goal.isActive {
            var inactive = goal
            inactive.isActive = false
            inactive.updatedAt = Date().epochMilliseconds
            try await repository.updateGoal(inactive)
        }

        if let current = goals.first(where: { $0.type == type && $0.isActive }) {
            var updated = current
            updated.targetMinutes = targetMinutes
            updated.weekStartDay = weekStartDay
            updated.isActive = true
            updated.updatedAt = Date().epochMilliseconds
            try await repository.updateGoal(updated)
        } else {
            try await repository.insertGoal(
                Goal(
                    type: type,
                    targetMinutes: targetMinutes,
                    weekStartDay: weekStartDay,
                    isActive: true
                )
            )
        }
    }
}

struct SaveStudySessionUseCase {
    let sessionRepository: StudySessionRepository
    let subjectRepository: SubjectRepository
    let materialRepository: MaterialRepository

    func saveManualSession(subjectId: Int64, materialId: Int64?, durationMinutes: Int, note: String?) async throws {
        guard let subject = try await subjectRepository.getSubjectById(subjectId) else {
            throw ValidationError(message: "科目を選択してください")
        }
        let materials = try await materialRepository.getAllMaterials()
        let material = materials.first(where: { $0.id == materialId })
        let materialName = material?.name ?? ""
        let end = Date().epochMilliseconds
        let start = end - Int64(durationMinutes * 60_000)
        try await sessionRepository.insertSession(
            StudySession(
                materialId: materialId,
                materialSyncId: material?.syncId,
                materialName: materialName,
                subjectId: subject.id,
                subjectSyncId: subject.syncId,
                subjectName: subject.name,
                startTime: start,
                endTime: end,
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
        let daily = reportDailyData(sessions: sortedSessions, reference: reference)
        let weekly = reportWeeklyData(sessions: sortedSessions, reference: reference)
        let monthly = reportMonthlyData(sessions: sortedSessions, reference: reference)
        let bySubject = subjectBreakdown(subjects: subjects, sessions: sortedSessions, reference: reference)

        return ReportsData(
            daily: daily,
            weekly: weekly,
            monthly: monthly,
            bySubject: bySubject,
            streakDays: streakDays(sessions: sortedSessions, reference: reference),
            bestStreak: bestStreak(sessions: sortedSessions)
        )
    }

    private func reportDailyData(sessions: [StudySession], reference: Date) -> [DailyStudyData] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"
        return (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: reference) else { return nil }
            let start = Calendar.current.startOfDay(for: date).epochMilliseconds
            let end = start + 86_400_000
            let minutes = sessions.filter { $0.startTime >= start && $0.startTime < end }.reduce(0) { $0 + $1.durationMinutes }
            return DailyStudyData(date: start, dateLabel: formatter.string(from: date), minutes: minutes, hours: Double(minutes) / 60)
        }
        .reversed()
    }

    private func reportWeeklyData(sessions: [StudySession], reference: Date) -> [WeeklyStudyData] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return (0..<4).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: reference) else { return nil }
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: date)
            let start = (interval?.start ?? date).epochMilliseconds
            let end = Int64((interval?.end ?? date).epochMilliseconds)
            let minutes = sessions.filter { $0.startTime >= start && $0.startTime <= end }.reduce(0) { $0 + $1.durationMinutes }
            return WeeklyStudyData(
                weekStart: start,
                weekLabel: "\(formatter.string(from: Date(epochMilliseconds: start)))週",
                hours: minutes / 60,
                minutes: minutes % 60
            )
        }
        .reversed()
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

extension Date {
    var epochMilliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1_000).rounded())
    }

    var epochDay: Int64 {
        let calendar = Calendar.current
        guard let epochStart = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: epochStart), to: calendar.startOfDay(for: self)).day ?? 0
        return Int64(days)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    init(epochMilliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(epochMilliseconds) / 1_000)
    }

    init(epochDay: Int64) {
        let calendar = Calendar.current
        guard let epochStart = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) else {
            self = Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
            return
        }
        self = calendar.date(byAdding: .day, value: Int(epochDay), to: calendar.startOfDay(for: epochStart))
            ?? Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
