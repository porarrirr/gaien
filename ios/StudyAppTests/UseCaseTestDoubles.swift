import Foundation
@testable import StudyApp

func testDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func testSession(
    id: Int64,
    day: Date,
    hour: Int,
    minutes: Int,
    subjectId: Int64 = 1,
    subjectName: String = "数学",
    materialId: Int64? = nil,
    materialName: String = "",
    sessionType: StudySessionType = .stopwatch,
    screenTimeUnlockExcluded: Bool = false,
    rating: Int? = nil
) -> StudySession {
    let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!.epochMilliseconds
    return StudySession(
        id: id,
        syncId: "session-\(id)",
        materialId: materialId,
        materialName: materialName,
        subjectId: subjectId,
        subjectSyncId: "subject-\(subjectId)",
        subjectName: subjectName,
        sessionType: sessionType,
        startTime: start,
        endTime: start + Int64(minutes * 60_000),
        rating: rating,
        screenTimeUnlockExcluded: screenTimeUnlockExcluded,
        createdAt: start,
        updatedAt: start
    )
}

final class TestSubjectRepository: SubjectRepository {
    var subjects: [Subject]

    init(_ subjects: [Subject] = []) {
        self.subjects = subjects
    }

    func getAllSubjects() async throws -> [Subject] { subjects }
    func getSubjectById(_ id: Int64) async throws -> Subject? { subjects.first { $0.id == id } }
    func insertSubject(_ subject: Subject) async throws -> Int64 { subjects.append(subject); return subject.id }
    func updateSubject(_ subject: Subject) async throws { subjects.removeAll { $0.id == subject.id }; subjects.append(subject) }
    func deleteSubject(_ subject: Subject) async throws {}
}

final class TestMaterialRepository: MaterialRepository {
    var materials: [Material]
    var updatedMaterials: [Material] = []

    init(_ materials: [Material] = []) {
        self.materials = materials
    }

    func getAllMaterials() async throws -> [Material] { materials }
    func getMaterialsBySubjectId(_ subjectId: Int64) async throws -> [Material] { materials.filter { $0.subjectId == subjectId } }
    func insertMaterial(_ material: Material) async throws -> Int64 { materials.append(material); return material.id }
    func updateMaterial(_ material: Material) async throws { updatedMaterials.append(material) }
    func deleteMaterial(_ material: Material) async throws {}
}

final class TestStudySessionRepository: StudySessionRepository {
    var sessions: [StudySession]
    var insertedSessions: [StudySession] = []
    var insertedSessionsWithReviews: [StudySession] = []

    init(_ sessions: [StudySession] = []) {
        self.sessions = sessions
    }

    func getAllSessions() async throws -> [StudySession] { sessions }

    func getSessionsBetweenDates(start: Int64, end: Int64) async throws -> [StudySession] {
        sessions.filter { $0.startTime >= start && $0.startTime < end }
    }

    func insertSession(_ session: StudySession) async throws -> Int64 {
        insertedSessions.append(session)
        return session.id
    }

    func insertSessionWithProblemReviews(_ session: StudySession) async throws -> Int64 {
        insertedSessionsWithReviews.append(session)
        return session.id
    }

    func updateSession(_ session: StudySession) async throws {}
    func deleteSession(_ session: StudySession) async throws {}
    func getDistinctStudyDays() async throws -> [Int64] { Array(Set(sessions.map(\.date))).sorted() }
}

final class TestProblemReviewRepository: ProblemReviewRepository {
    var records: [ProblemReviewRecord]
    var todayProblems: [TodayReviewProblem]

    init(records: [ProblemReviewRecord] = [], todayProblems: [TodayReviewProblem] = []) {
        self.records = records
        self.todayProblems = todayProblems
    }

    func getAllProblemReviewRecords() async throws -> [ProblemReviewRecord] { records }
    func getTodayReviewProblems(reference: Date) async throws -> [TodayReviewProblem] { todayProblems }
}

final class TestGoalRepository: GoalRepository {
    var goals: [Goal]
    var insertedGoals: [Goal] = []
    var updatedGoals: [Goal] = []

    init(_ goals: [Goal] = []) {
        self.goals = goals
    }

    func getAllGoals() async throws -> [Goal] { goals }
    func getActiveGoalByType(_ type: GoalType) async throws -> Goal? { goals.first { $0.type == type && $0.isActive && $0.deletedAt == nil } }
    func insertGoal(_ goal: Goal) async throws -> Int64 { insertedGoals.append(goal); return goal.id }
    func updateGoal(_ goal: Goal) async throws { updatedGoals.append(goal) }
    func deleteGoal(_ goal: Goal) async throws {}
}

final class TestExamRepository: ExamRepository {
    var exams: [Exam]

    init(_ exams: [Exam] = []) {
        self.exams = exams
    }

    func getAllExams() async throws -> [Exam] { exams }
    func getUpcomingExams(now: Date) async throws -> [Exam] { exams }
    func insertExam(_ exam: Exam) async throws -> Int64 { exams.append(exam); return exam.id }
    func updateExam(_ exam: Exam) async throws {}
    func deleteExam(_ exam: Exam) async throws {}
}

final class TestPlanRepository: PlanRepository {
    var plans: [StudyPlan]
    var createdPlans: [(StudyPlan, [PlanItem])] = []

    init(_ plans: [StudyPlan] = []) {
        self.plans = plans
    }

    func getAllPlans() async throws -> [StudyPlan] { plans }
    func getPlanItems(planId: Int64) async throws -> [PlanItem] { [] }
    func createPlan(_ plan: StudyPlan, items: [PlanItem]) async throws -> Int64 { createdPlans.append((plan, items)); return 1 }
    func insertPlanItem(_ item: PlanItem) async throws -> Int64 { item.id }
    func updatePlanItem(_ item: PlanItem) async throws {}
    func deletePlanItem(_ item: PlanItem) async throws {}
    func deletePlan(_ plan: StudyPlan) async throws {}
}

final class TestTimetableRepository: TimetableRepository {
    var periods: [TimetablePeriod]
    var terms: [TimetableTerm]
    var entries: [TimetableEntry]
    var reviews: [TimetableReviewRecord]

    init(
        periods: [TimetablePeriod] = [],
        terms: [TimetableTerm] = [],
        entries: [TimetableEntry] = [],
        reviews: [TimetableReviewRecord] = []
    ) {
        self.periods = periods
        self.terms = terms
        self.entries = entries
        self.reviews = reviews
    }

    func getAllTimetablePeriods() async throws -> [TimetablePeriod] { periods }
    func saveTimetablePeriod(_ period: TimetablePeriod) async throws -> Int64 { period.id }
    func deleteTimetablePeriod(_ period: TimetablePeriod) async throws {}
    func getAllTimetableTerms() async throws -> [TimetableTerm] { terms }
    func saveTimetableTerm(_ term: TimetableTerm) async throws -> Int64 { term.id }
    func deleteTimetableTerm(_ term: TimetableTerm) async throws {}
    func getAllTimetableEntries() async throws -> [TimetableEntry] { entries }
    func saveTimetableEntry(_ entry: TimetableEntry) async throws -> Int64 { entry.id }
    func deleteTimetableEntry(_ entry: TimetableEntry) async throws {}
    func getAllTimetableReviewRecords() async throws -> [TimetableReviewRecord] { reviews }
    func saveTimetableReviewRecord(_ record: TimetableReviewRecord) async throws -> Int64 { record.id }
    func deleteTimetableReviewRecord(_ record: TimetableReviewRecord) async throws {}
}
