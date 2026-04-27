import Foundation

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
    var segments: [SubjectStudySegment] = []
}

struct WeeklyStudyData: Identifiable, Hashable {
    var id: Int64 { weekStart }
    var weekStart: Int64
    var weekLabel: String
    var hours: Int
    var minutes: Int
    var segments: [SubjectStudySegment] = []
}

struct SubjectStudySegment: Identifiable, Hashable {
    var id: Int64 { subjectId }
    var subjectId: Int64
    var subjectName: String
    var minutes: Int
    var color: Int
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

struct RatingAverageSummary: Hashable {
    var average: Double?
    var ratedMinutes: Int
}

struct RatingAveragesData: Hashable {
    var today: RatingAverageSummary
    var week: RatingAverageSummary
    var month: RatingAverageSummary
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
    enum Mode: String, Codable, Equatable {
        case stopwatch = "STOPWATCH"
        case timer = "TIMER"
    }

    var subjectId: Int64
    var materialId: Int64?
    var startedAt: Int64?
    var accumulatedMilliseconds: Int64
    var completedIntervals: [StudySessionInterval] = []
    var mode: Mode = .stopwatch
    var targetDurationMilliseconds: Int64?
    var isRunning: Bool

    private enum CodingKeys: String, CodingKey {
        case subjectId
        case materialId
        case startedAt
        case accumulatedMilliseconds
        case completedIntervals
        case mode
        case targetDurationMilliseconds
        case isRunning
    }

    func elapsedTime(at now: Date = Date()) -> Int64 {
        if isRunning, let startedAt {
            return accumulatedMilliseconds + max(now.epochMilliseconds - startedAt, 0)
        }
        return accumulatedMilliseconds
    }

    func finalizedIntervals(at now: Date = Date()) -> [StudySessionInterval] {
        if isRunning, let startedAt {
            return completedIntervals + [StudySessionInterval(startTime: startedAt, endTime: now.epochMilliseconds)]
        }
        return completedIntervals
    }

    func remainingTime(at now: Date = Date()) -> Int64 {
        guard mode == .timer else { return 0 }
        return max((targetDurationMilliseconds ?? 0) - elapsedTime(at: now), 0)
    }

    var sessionType: StudySessionType {
        switch mode {
        case .stopwatch: return .stopwatch
        case .timer: return .timer
        }
    }

    init(
        subjectId: Int64,
        materialId: Int64?,
        startedAt: Int64?,
        accumulatedMilliseconds: Int64,
        completedIntervals: [StudySessionInterval] = [],
        mode: Mode = .stopwatch,
        targetDurationMilliseconds: Int64? = nil,
        isRunning: Bool
    ) {
        self.subjectId = subjectId
        self.materialId = materialId
        self.startedAt = startedAt
        self.accumulatedMilliseconds = accumulatedMilliseconds
        self.completedIntervals = completedIntervals
        self.mode = mode
        self.targetDurationMilliseconds = targetDurationMilliseconds
        self.isRunning = isRunning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subjectId = try container.decode(Int64.self, forKey: .subjectId)
        materialId = try container.decodeIfPresent(Int64.self, forKey: .materialId)
        startedAt = try container.decodeIfPresent(Int64.self, forKey: .startedAt)
        accumulatedMilliseconds = try container.decodeIfPresent(Int64.self, forKey: .accumulatedMilliseconds) ?? 0
        completedIntervals = try container.decodeIfPresent([StudySessionInterval].self, forKey: .completedIntervals) ?? []
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .stopwatch
        targetDurationMilliseconds = try container.decodeIfPresent(Int64.self, forKey: .targetDurationMilliseconds)
        isRunning = try container.decode(Bool.self, forKey: .isRunning)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subjectId, forKey: .subjectId)
        try container.encodeIfPresent(materialId, forKey: .materialId)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encode(accumulatedMilliseconds, forKey: .accumulatedMilliseconds)
        try container.encode(completedIntervals, forKey: .completedIntervals)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(targetDurationMilliseconds, forKey: .targetDurationMilliseconds)
        try container.encode(isRunning, forKey: .isRunning)
    }
}

struct AppPreferences: Codable, Equatable {
    var onboardingCompleted = false
    var reminderEnabled = false
    var reminderHour = 19
    var reminderMinute = 0
    var selectedColorTheme: ColorTheme = .green
    var selectedThemeMode: ThemeMode = .system
    var liveActivityEnabled = true
    var liveActivityDisplayPreset: LiveActivityDisplayPreset = .standard
    var activeTimer: TimerSnapshot?

    private enum CodingKeys: String, CodingKey {
        case onboardingCompleted
        case reminderEnabled
        case reminderHour
        case reminderMinute
        case selectedColorTheme
        case selectedThemeMode
        case liveActivityEnabled
        case liveActivityDisplayPreset
        case activeTimer
    }

    init(
        onboardingCompleted: Bool = false,
        reminderEnabled: Bool = false,
        reminderHour: Int = 19,
        reminderMinute: Int = 0,
        selectedColorTheme: ColorTheme = .green,
        selectedThemeMode: ThemeMode = .system,
        liveActivityEnabled: Bool = true,
        liveActivityDisplayPreset: LiveActivityDisplayPreset = .standard,
        activeTimer: TimerSnapshot? = nil
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.selectedColorTheme = selectedColorTheme
        self.selectedThemeMode = selectedThemeMode
        self.liveActivityEnabled = liveActivityEnabled
        self.liveActivityDisplayPreset = liveActivityDisplayPreset
        self.activeTimer = activeTimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 19
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        selectedColorTheme = try container.decodeIfPresent(ColorTheme.self, forKey: .selectedColorTheme) ?? .green
        selectedThemeMode = try container.decodeIfPresent(ThemeMode.self, forKey: .selectedThemeMode) ?? .system
        liveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? true
        liveActivityDisplayPreset = try container.decodeIfPresent(LiveActivityDisplayPreset.self, forKey: .liveActivityDisplayPreset) ?? .standard
        activeTimer = try container.decodeIfPresent(TimerSnapshot.self, forKey: .activeTimer)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminderHour, forKey: .reminderHour)
        try container.encode(reminderMinute, forKey: .reminderMinute)
        try container.encode(selectedColorTheme, forKey: .selectedColorTheme)
        try container.encode(selectedThemeMode, forKey: .selectedThemeMode)
        try container.encode(liveActivityEnabled, forKey: .liveActivityEnabled)
        try container.encode(liveActivityDisplayPreset, forKey: .liveActivityDisplayPreset)
        try container.encodeIfPresent(activeTimer, forKey: .activeTimer)
    }
}

struct StudySessionInterval: Codable, Hashable {
    var startTime: Int64
    var endTime: Int64

    var duration: Int64 {
        max(endTime - startTime, 0)
    }
}
