import Foundation

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
    var pendingConflictCount = 0
    var requiresResolution: Bool { pendingConflictCount > 0 }
}

struct HomeData: Hashable {
    var todayStudyMinutes: Int
    var todaySessions: [TodaySession]
    var todayGoal: Goal?
    var weeklyGoal: Goal?
    var weeklyStudyMinutes: Int
    var upcomingExams: [Exam]
    var timetableLesson: TimetableLesson? = nil
    var upcomingTimetableLesson: TimetableLesson? = nil
    var todayReviewProblems: [TodayReviewProblem] = []
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
    var ratingAverages: RatingAveragesData
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
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var supportsProblemRecords: Bool
    var subjects: [Subject]
    var materials: [Material]
    var sessions: [StudySession]
    var goals: [Goal]
    var exams: [Exam]
    var plans: [PlanData]
    var timetablePeriods: [TimetablePeriod]
    var timetableEntries: [TimetableEntry]
    var timetableTerms: [TimetableTerm]
    var timetableReviewRecords: [TimetableReviewRecord]
    var problemReviewRecords: [ProblemReviewRecord]
    var exportDate: Int64

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case supportsProblemRecords
        case subjects
        case materials
        case sessions
        case goals
        case exams
        case plans
        case timetablePeriods
        case timetableEntries
        case timetableTerms
        case timetableReviewRecords
        case problemReviewRecords
        case exportDate
    }

    init(
        schemaVersion: Int = AppData.currentSchemaVersion,
        supportsProblemRecords: Bool = true,
        subjects: [Subject],
        materials: [Material],
        sessions: [StudySession],
        goals: [Goal],
        exams: [Exam],
        plans: [PlanData],
        timetablePeriods: [TimetablePeriod] = [],
        timetableEntries: [TimetableEntry] = [],
        timetableTerms: [TimetableTerm] = [],
        timetableReviewRecords: [TimetableReviewRecord] = [],
        problemReviewRecords: [ProblemReviewRecord] = [],
        exportDate: Int64
    ) {
        self.schemaVersion = schemaVersion
        self.supportsProblemRecords = supportsProblemRecords
        self.subjects = subjects
        self.materials = materials
        self.sessions = sessions
        self.goals = goals
        self.exams = exams
        self.plans = plans
        self.timetablePeriods = timetablePeriods
        self.timetableEntries = timetableEntries
        self.timetableTerms = timetableTerms
        self.timetableReviewRecords = timetableReviewRecords
        self.problemReviewRecords = problemReviewRecords
        self.exportDate = exportDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        supportsProblemRecords = try container.decodeIfPresent(Bool.self, forKey: .supportsProblemRecords) ?? false
        subjects = try container.decodeIfPresent([Subject].self, forKey: .subjects) ?? []
        materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        sessions = try container.decodeIfPresent([StudySession].self, forKey: .sessions) ?? []
        goals = try container.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        exams = try container.decodeIfPresent([Exam].self, forKey: .exams) ?? []
        plans = try container.decodeIfPresent([PlanData].self, forKey: .plans) ?? []
        timetablePeriods = try container.decodeIfPresent([TimetablePeriod].self, forKey: .timetablePeriods) ?? []
        timetableEntries = try container.decodeIfPresent([TimetableEntry].self, forKey: .timetableEntries) ?? []
        timetableTerms = try container.decodeIfPresent([TimetableTerm].self, forKey: .timetableTerms) ?? []
        timetableReviewRecords = try container.decodeIfPresent([TimetableReviewRecord].self, forKey: .timetableReviewRecords) ?? []
        problemReviewRecords = try container.decodeIfPresent([ProblemReviewRecord].self, forKey: .problemReviewRecords) ?? []
        exportDate = try container.decodeIfPresent(Int64.self, forKey: .exportDate) ?? Date().epochMilliseconds
    }
}
