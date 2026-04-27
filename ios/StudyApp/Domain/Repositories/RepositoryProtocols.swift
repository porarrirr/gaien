import Foundation

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
    func clearLocalSyncState() async
}
