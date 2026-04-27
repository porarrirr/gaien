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
}

struct HomeData: Hashable {
    var todayStudyMinutes: Int
    var todaySessions: [TodaySession]
    var todayGoal: Goal?
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
    var subjects: [Subject]
    var materials: [Material]
    var sessions: [StudySession]
    var goals: [Goal]
    var exams: [Exam]
    var plans: [PlanData]
    var exportDate: Int64
}
