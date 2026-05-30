import XCTest
@testable import StudyApp

final class GetHomeDataUseCaseTests: XCTestCase {
    func test_execute_combinesHomeSummaryAndPassesThroughReviewProblems() async throws {
        let reference = testDate(2026, 5, 4, hour: 9, minute: 30)
        let today = reference.startOfDay
        let todayLate = testSession(id: 2, day: today, hour: 18, minutes: 35, subjectId: 2, subjectName: "英語", materialName: "単語帳")
        let todayEarly = testSession(id: 1, day: today, hour: 8, minutes: 25, subjectId: 1, subjectName: "数学", materialName: "問題集")
        let weekLater = testSession(id: 3, day: testDate(2026, 5, 5), hour: 10, minutes: 40, subjectId: 1, subjectName: "数学")
        let todayProblem = TodayReviewProblem(
            materialId: 10,
            materialName: "数学問題集",
            subjectName: "数学",
            problemNumber: 12,
            problemLabel: "12問",
            nextReviewDate: reference.epochMilliseconds,
            consecutiveCorrectCount: 0,
            wrongCount: 2
        )
        let firstPeriod = TimetablePeriod(id: 1, name: "1限", startMinute: 9 * 60, endMinute: 10 * 60, sortOrder: 1)
        let secondPeriod = TimetablePeriod(id: 2, name: "2限", startMinute: 11 * 60, endMinute: 12 * 60, sortOrder: 2)
        let term = TimetableTerm(id: 1, name: "前期", startDate: today.epochDay, endDate: testDate(2026, 5, 10).epochDay)
        let useCase = GetHomeDataUseCase(
            studySessionRepository: TestStudySessionRepository([todayEarly, todayLate, weekLater]),
            goalRepository: TestGoalRepository([
                Goal(id: 1, type: .daily, targetMinutes: 30, dayOfWeek: .monday, updatedAt: 100),
                Goal(id: 2, type: .daily, targetMinutes: 90, dayOfWeek: .monday, updatedAt: 200),
                Goal(id: 3, type: .weekly, targetMinutes: 420, updatedAt: 100)
            ]),
            examRepository: TestExamRepository([
                Exam(id: 1, name: "期末", date: testDate(2026, 5, 14).epochDay),
                Exam(id: 2, name: "小テスト", date: testDate(2026, 5, 7).epochDay)
            ]),
            timetableRepository: TestTimetableRepository(
                periods: [secondPeriod, firstPeriod],
                terms: [term],
                entries: [
                    TimetableEntry(id: 1, termId: 1, dayOfWeek: .monday, periodId: 1, subjectName: "数学"),
                    TimetableEntry(id: 2, termId: 1, dayOfWeek: .monday, periodId: 2, subjectName: "英語")
                ]
            ),
            problemReviewRepository: TestProblemReviewRepository(todayProblems: [todayProblem]),
            clock: Clock(nowProvider: { reference })
        )

        let result = try await useCase.execute()

        XCTAssertEqual(result.todayStudyMinutes, 60)
        XCTAssertEqual(result.todaySessions.map(\.id), [2, 1])
        XCTAssertEqual(result.todayGoal?.targetMinutes, 90)
        XCTAssertEqual(result.weeklyGoal?.targetMinutes, 420)
        XCTAssertEqual(result.weeklyStudyMinutes, 100)
        XCTAssertEqual(result.upcomingExams.map(\.name), ["小テスト", "期末"])
        XCTAssertEqual(result.timetableLesson?.entry.subjectName, "数学")
        XCTAssertEqual(result.upcomingTimetableLesson?.entry.subjectName, "英語")
        XCTAssertEqual(result.todayReviewProblems, [todayProblem])
    }

    func test_execute_omitsTimetableLessonsWhenNoActivePeriodExists() async throws {
        let reference = testDate(2026, 5, 4, hour: 9, minute: 30)
        let useCase = GetHomeDataUseCase(
            studySessionRepository: TestStudySessionRepository(),
            goalRepository: TestGoalRepository(),
            examRepository: TestExamRepository(),
            timetableRepository: TestTimetableRepository(
                periods: [TimetablePeriod(id: 1, name: "invalid", startMinute: 600, endMinute: 600, sortOrder: 1)],
                terms: [TimetableTerm(id: 1, name: "前期", startDate: reference.epochDay, endDate: reference.epochDay)],
                entries: [TimetableEntry(id: 1, termId: 1, dayOfWeek: .monday, periodId: 1, subjectName: "数学")]
            ),
            problemReviewRepository: TestProblemReviewRepository(),
            clock: Clock(nowProvider: { reference })
        )

        let result = try await useCase.execute()

        XCTAssertNil(result.timetableLesson)
        XCTAssertNil(result.upcomingTimetableLesson)
        XCTAssertTrue(result.todayReviewProblems.isEmpty)
    }
}
