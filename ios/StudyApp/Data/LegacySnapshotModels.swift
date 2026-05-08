import Foundation

struct LegacySnapshot: Codable {
    var subjects: [LegacySubject] = []
    var materials: [LegacyMaterial] = []
    var sessions: [LegacySession] = []
    var goals: [LegacyGoal] = []
    var exams: [LegacyExam] = []
    var plans: [LegacyPlan] = []
    var planItems: [LegacyPlanItem] = []
    var onboardingCompleted = false
    var reminderEnabled = false
    var reminderHour = 19
    var reminderMinute = 0
    var selectedColorTheme: ColorTheme = .green
    var selectedThemeMode: ThemeMode = .system
    var liveActivityEnabled = true
    var liveActivityDisplayPreset: LiveActivityDisplayPreset = .standard
    var landscapeTimerDisplayPreset: LandscapeTimerDisplayPreset = .problemProgress
    var activeTimer: LegacyTimerSnapshot?

    private enum CodingKeys: String, CodingKey {
        case subjects
        case materials
        case sessions
        case goals
        case exams
        case plans
        case planItems
        case onboardingCompleted
        case reminderEnabled
        case reminderHour
        case reminderMinute
        case selectedColorTheme
        case selectedThemeMode
        case liveActivityEnabled
        case liveActivityDisplayPreset
        case landscapeTimerDisplayPreset
        case activeTimer
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subjects = try container.decodeIfPresent([LegacySubject].self, forKey: .subjects) ?? []
        materials = try container.decodeIfPresent([LegacyMaterial].self, forKey: .materials) ?? []
        sessions = try container.decodeIfPresent([LegacySession].self, forKey: .sessions) ?? []
        goals = try container.decodeIfPresent([LegacyGoal].self, forKey: .goals) ?? []
        exams = try container.decodeIfPresent([LegacyExam].self, forKey: .exams) ?? []
        plans = try container.decodeIfPresent([LegacyPlan].self, forKey: .plans) ?? []
        planItems = try container.decodeIfPresent([LegacyPlanItem].self, forKey: .planItems) ?? []
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 19
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        selectedColorTheme = try container.decodeIfPresent(ColorTheme.self, forKey: .selectedColorTheme) ?? .green
        selectedThemeMode = try container.decodeIfPresent(ThemeMode.self, forKey: .selectedThemeMode) ?? .system
        liveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? true
        liveActivityDisplayPreset = try container.decodeIfPresent(LiveActivityDisplayPreset.self, forKey: .liveActivityDisplayPreset) ?? .standard
        landscapeTimerDisplayPreset = try container.decodeIfPresent(LandscapeTimerDisplayPreset.self, forKey: .landscapeTimerDisplayPreset) ?? .problemProgress
        activeTimer = try container.decodeIfPresent(LegacyTimerSnapshot.self, forKey: .activeTimer)
    }

    var preferences: AppPreferences {
        AppPreferences(
            onboardingCompleted: onboardingCompleted,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            selectedColorTheme: selectedColorTheme,
            selectedThemeMode: selectedThemeMode,
            liveActivityEnabled: liveActivityEnabled,
            liveActivityDisplayPreset: liveActivityDisplayPreset,
            landscapeTimerDisplayPreset: landscapeTimerDisplayPreset,
            activeTimer: activeTimer?.model
        )
    }
}

struct LegacySubject: Codable {
    var id: Int64
    var name: String
    var color: Int
    var icon: SubjectIcon?
}

struct LegacyMaterial: Codable {
    var id: Int64
    var name: String
    var subjectId: Int64
    var totalPages: Int
    var currentPage: Int
    var color: Int?
    var note: String?
}

struct LegacySession: Codable {
    var id: Int64
    var materialId: Int64?
    var materialName: String
    var subjectId: Int64
    var subjectName: String
    var startTime: Date
    var endTime: Date
    var note: String?
}

struct LegacyGoal: Codable {
    var id: Int64
    var type: GoalType
    var targetMinutes: Int
    var dayOfWeek: StudyWeekday?
    var weekStartDay: StudyWeekday
    var isActive: Bool
}

struct LegacyExam: Codable {
    var id: Int64
    var name: String
    var date: Date
    var note: String?
}

struct LegacyPlan: Codable {
    var id: Int64
    var name: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var createdAt: Date
}

struct LegacyPlanItem: Codable {
    var id: Int64
    var planId: Int64
    var subjectId: Int64
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int
    var timeSlot: String?
}

struct LegacyTimerSnapshot: Codable {
    var subjectId: Int64
    var materialId: Int64?
    var startedAt: Date?
    var accumulatedSeconds: TimeInterval
    var isRunning: Bool

    var model: TimerSnapshot {
        TimerSnapshot(
            subjectId: subjectId,
            materialId: materialId,
            startedAt: startedAt?.epochMilliseconds,
            accumulatedMilliseconds: Int64(accumulatedSeconds * 1_000),
            isRunning: isRunning
        )
    }
}
