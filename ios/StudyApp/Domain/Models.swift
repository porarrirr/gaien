import Foundation
import SwiftUI

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

    var title: String {
        switch self {
        case .book: return "読書"
        case .calculator: return "数学"
        case .flask: return "理科"
        case .globe: return "地理"
        case .palette: return "美術"
        case .music: return "音楽"
        case .code: return "プログラミング"
        case .atom: return "化学"
        case .dna: return "生物"
        case .brain: return "思考"
        case .language: return "語学"
        case .history: return "歴史"
        case .other: return "その他"
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

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

enum ColorTheme: String, CaseIterable, Codable, Identifiable, Hashable {
    case green
    case blue
    case purple
    case orange
    case red
    case teal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green: return "グリーン"
        case .blue: return "ブルー"
        case .purple: return "パープル"
        case .orange: return "オレンジ"
        case .red: return "レッド"
        case .teal: return "ティール"
        }
    }

    var hex: Int {
        switch self {
        case .green: return 0x4CAF50
        case .blue: return 0x2196F3
        case .purple: return 0x9C27B0
        case .orange: return 0xFF9800
        case .red: return 0xF44336
        case .teal: return 0x009688
        }
    }

    var accentHex: Int {
        switch self {
        case .green: return 0x2196F3
        case .blue: return 0x4CAF50
        case .purple: return 0xFF9800
        case .orange: return 0x2196F3
        case .red: return 0xFF9800
        case .teal: return 0x4CAF50
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }

    var title: String {
        rawValue.uppercased()
    }
}

struct Subject: Identifiable, Codable, Hashable {
    var id: Int64
    var name: String
    var color: Int
    var icon: SubjectIcon?
}

struct Material: Identifiable, Codable, Hashable {
    var id: Int64
    var name: String
    var subjectId: Int64
    var totalPages: Int
    var currentPage: Int
    var color: Int?
    var note: String?

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(max(Double(currentPage) / Double(totalPages), 0), 1)
    }

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }
}

struct StudySession: Identifiable, Codable, Hashable {
    var id: Int64
    var materialId: Int64?
    var materialName: String
    var subjectId: Int64
    var subjectName: String
    var startTime: Date
    var endTime: Date
    var note: String?

    var duration: TimeInterval {
        max(endTime.timeIntervalSince(startTime), 0)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var durationHours: Double {
        duration / 3600
    }

    var durationFormatted: String {
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var durationJapaneseText: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)時間\(minutes)分"
        }
        if hours > 0 {
            return "\(hours)時間"
        }
        return "\(minutes)分"
    }

    var dayOfWeek: StudyWeekday {
        StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: startTime))
    }
}

struct Goal: Identifiable, Codable, Hashable {
    var id: Int64
    var type: GoalType
    var targetMinutes: Int
    var weekStartDay: StudyWeekday
    var isActive: Bool

    var targetHours: Double {
        Double(targetMinutes) / 60.0
    }

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
    var id: Int64
    var name: String
    var date: Date
    var note: String?

    func daysRemaining(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func isPast(from referenceDate: Date = Date()) -> Bool {
        daysRemaining(from: referenceDate) < 0
    }

    func isToday(from referenceDate: Date = Date()) -> Bool {
        daysRemaining(from: referenceDate) == 0
    }
}

struct StudyPlan: Identifiable, Codable, Hashable {
    var id: Int64
    var name: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var createdAt: Date
}

struct PlanItem: Identifiable, Codable, Hashable {
    var id: Int64
    var planId: Int64
    var subjectId: Int64
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int
    var timeSlot: String?
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
    var weekStart: Date
    var weekEnd: Date
    var totalTargetMinutes: Int
    var totalActualMinutes: Int
    var dailyBreakdown: [StudyWeekday: DailyPlanSummary]
}

struct DailyStudyData: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var dateLabel: String
    var minutes: Int
    var hours: Double
}

struct WeeklyStudyData: Identifiable, Hashable {
    var id: Date { weekStart }
    var weekStart: Date
    var weekLabel: String
    var hours: Int
    var minutes: Int
}

struct MonthlyStudyData: Identifiable, Hashable {
    var id: Date { monthStart }
    var monthStart: Date
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

struct BookInfo: Codable, Hashable {
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
    var startedAt: Date?
    var accumulatedSeconds: TimeInterval
    var isRunning: Bool

    func elapsedTime(at now: Date = Date()) -> TimeInterval {
        if isRunning, let startedAt {
            return accumulatedSeconds + now.timeIntervalSince(startedAt)
        }
        return accumulatedSeconds
    }
}

struct AppSnapshot: Codable, Equatable {
    var lastIdentifier: Int64 = 0
    var subjects: [Subject] = []
    var materials: [Material] = []
    var sessions: [StudySession] = []
    var goals: [Goal] = []
    var exams: [Exam] = []
    var plans: [StudyPlan] = []
    var planItems: [PlanItem] = []
    var onboardingCompleted = false
    var reminderEnabled = false
    var reminderHour = 19
    var reminderMinute = 0
    var selectedColorTheme: ColorTheme = .green
    var selectedThemeMode: ThemeMode = .system
    var activeTimer: TimerSnapshot?

    static let empty = AppSnapshot()
}

struct BackupPlanData: Codable {
    var plan: BackupStudyPlan
    var items: [BackupPlanItem]
}

struct AppBackup: Codable {
    var subjects: [BackupSubject]
    var materials: [BackupMaterial]
    var sessions: [BackupStudySession]
    var goals: [BackupGoal]
    var exams: [BackupExam]
    var plans: [BackupPlanData]
    var exportDate: Int64

    static func make(from snapshot: AppSnapshot) -> AppBackup {
        let planItemsByPlan = Dictionary(grouping: snapshot.planItems, by: \.planId)
        return AppBackup(
            subjects: snapshot.subjects.map(BackupSubject.init),
            materials: snapshot.materials.map(BackupMaterial.init),
            sessions: snapshot.sessions.map(BackupStudySession.init),
            goals: snapshot.goals.map(BackupGoal.init),
            exams: snapshot.exams.map(BackupExam.init),
            plans: snapshot.plans.map { plan in
                BackupPlanData(
                    plan: BackupStudyPlan(plan),
                    items: (planItemsByPlan[plan.id] ?? []).map(BackupPlanItem.init)
                )
            },
            exportDate: Date().epochMilliseconds
        )
    }

    func asSnapshot(preserving current: AppSnapshot) -> AppSnapshot {
        let subjects = subjects.map(\.model)
        let materials = materials.map(\.model)
        let sessions = sessions.map(\.model)
        let goals = goals.map(\.model)
        let exams = exams.map(\.model)
        let backupPlans = plans
        let plans = backupPlans.map(\.plan.model)
        let planItems = backupPlans.flatMap { $0.items.map(\.model) }

        let allIdentifiers =
            subjects.map(\.id) +
            materials.map(\.id) +
            sessions.map(\.id) +
            goals.map(\.id) +
            exams.map(\.id) +
            plans.map(\.id) +
            planItems.map(\.id)
        let maxIdentifier = allIdentifiers.max() ?? current.lastIdentifier

        return AppSnapshot(
            lastIdentifier: maxIdentifier,
            subjects: subjects,
            materials: materials,
            sessions: sessions,
            goals: goals,
            exams: exams,
            plans: plans,
            planItems: planItems,
            onboardingCompleted: current.onboardingCompleted,
            reminderEnabled: current.reminderEnabled,
            reminderHour: current.reminderHour,
            reminderMinute: current.reminderMinute,
            selectedColorTheme: current.selectedColorTheme,
            selectedThemeMode: current.selectedThemeMode,
            activeTimer: nil
        )
    }
}

struct BackupSubject: Codable {
    var id: Int64
    var name: String
    var color: Int
    var icon: String?

    init(_ model: Subject) {
        id = model.id
        name = model.name
        color = model.color
        icon = model.icon?.rawValue
    }

    var model: Subject {
        Subject(id: id, name: name, color: color, icon: icon.flatMap(SubjectIcon.init(rawValue:)))
    }
}

struct BackupMaterial: Codable {
    var id: Int64
    var name: String
    var subjectId: Int64
    var totalPages: Int
    var currentPage: Int
    var color: Int?
    var note: String?

    init(_ model: Material) {
        id = model.id
        name = model.name
        subjectId = model.subjectId
        totalPages = model.totalPages
        currentPage = model.currentPage
        color = model.color
        note = model.note
    }

    var model: Material {
        Material(
            id: id,
            name: name,
            subjectId: subjectId,
            totalPages: totalPages,
            currentPage: currentPage,
            color: color,
            note: note
        )
    }
}

struct BackupStudySession: Codable {
    var id: Int64
    var materialId: Int64?
    var materialName: String
    var subjectId: Int64
    var subjectName: String
    var startTime: Int64
    var endTime: Int64
    var note: String?

    init(_ model: StudySession) {
        id = model.id
        materialId = model.materialId
        materialName = model.materialName
        subjectId = model.subjectId
        subjectName = model.subjectName
        startTime = model.startTime.epochMilliseconds
        endTime = model.endTime.epochMilliseconds
        note = model.note
    }

    var model: StudySession {
        StudySession(
            id: id,
            materialId: materialId,
            materialName: materialName,
            subjectId: subjectId,
            subjectName: subjectName,
            startTime: Date(epochMilliseconds: startTime),
            endTime: Date(epochMilliseconds: endTime),
            note: note
        )
    }
}

struct BackupGoal: Codable {
    var id: Int64
    var type: String
    var targetMinutes: Int
    var weekStartDay: String
    var isActive: Bool

    init(_ model: Goal) {
        id = model.id
        type = model.type.rawValue
        targetMinutes = model.targetMinutes
        weekStartDay = model.weekStartDay.rawValue
        isActive = model.isActive
    }

    var model: Goal {
        Goal(
            id: id,
            type: GoalType(rawValue: type) ?? .daily,
            targetMinutes: targetMinutes,
            weekStartDay: StudyWeekday(rawValue: weekStartDay) ?? .monday,
            isActive: isActive
        )
    }
}

struct BackupExam: Codable {
    var id: Int64
    var name: String
    var date: Int64
    var note: String?

    init(_ model: Exam) {
        id = model.id
        name = model.name
        date = model.date.epochDay
        note = model.note
    }

    var model: Exam {
        Exam(id: id, name: name, date: Date(epochDay: date), note: note)
    }
}

struct BackupStudyPlan: Codable {
    var id: Int64
    var name: String
    var startDate: Int64
    var endDate: Int64
    var isActive: Bool
    var createdAt: Int64

    init(_ model: StudyPlan) {
        id = model.id
        name = model.name
        startDate = model.startDate.epochMilliseconds
        endDate = model.endDate.epochMilliseconds
        isActive = model.isActive
        createdAt = model.createdAt.epochMilliseconds
    }

    var model: StudyPlan {
        StudyPlan(
            id: id,
            name: name,
            startDate: Date(epochMilliseconds: startDate),
            endDate: Date(epochMilliseconds: endDate),
            isActive: isActive,
            createdAt: Date(epochMilliseconds: createdAt)
        )
    }
}

struct BackupPlanItem: Codable {
    var id: Int64
    var planId: Int64
    var subjectId: Int64
    var dayOfWeek: String
    var targetMinutes: Int
    var actualMinutes: Int
    var timeSlot: String?

    init(_ model: PlanItem) {
        id = model.id
        planId = model.planId
        subjectId = model.subjectId
        dayOfWeek = model.dayOfWeek.rawValue
        targetMinutes = model.targetMinutes
        actualMinutes = model.actualMinutes
        timeSlot = model.timeSlot
    }

    var model: PlanItem {
        PlanItem(
            id: id,
            planId: planId,
            subjectId: subjectId,
            dayOfWeek: StudyWeekday(rawValue: dayOfWeek) ?? .monday,
            targetMinutes: targetMinutes,
            actualMinutes: actualMinutes,
            timeSlot: timeSlot
        )
    }
}

extension Date {
    var epochMilliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }

    var epochDay: Int64 {
        Int64(Calendar.current.startOfDay(for: self).timeIntervalSince1970 / 86_400)
    }

    init(epochMilliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(epochMilliseconds) / 1000)
    }

    init(epochDay: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
    }
}
