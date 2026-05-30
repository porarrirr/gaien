import XCTest
@testable import StudyApp

final class GetReportsDataUseCaseTests: XCTestCase {
    func test_execute_buildsExactReportBucketsAndStreaks() async throws {
        let reference = testDate(2026, 5, 6, hour: 20)
        let math = Subject(id: 1, syncId: "subject-1", name: "数学", color: 1)
        let english = Subject(id: 2, syncId: "subject-2", name: "英語", color: 2)
        let sessions = [
            testSession(id: 1, day: testDate(2026, 5, 6), hour: 8, minutes: 60, subjectId: 1, subjectName: "数学", rating: 5),
            testSession(id: 2, day: testDate(2026, 5, 6), hour: 11, minutes: 30, subjectId: 2, subjectName: "英語", rating: 3),
            testSession(id: 3, day: testDate(2026, 5, 5), hour: 9, minutes: 45, subjectId: 1, subjectName: "数学"),
            testSession(id: 4, day: testDate(2026, 5, 4), hour: 18, minutes: 15, subjectId: 1, subjectName: "数学"),
            testSession(id: 5, day: testDate(2026, 4, 28), hour: 7, minutes: 120, subjectId: 1, subjectName: "数学"),
            testSession(id: 6, day: testDate(2026, 4, 29), hour: 7, minutes: 60, subjectId: 1, subjectName: "数学"),
            testSession(id: 7, day: testDate(2026, 4, 30), hour: 7, minutes: 30, subjectId: 1, subjectName: "数学"),
            testSession(id: 8, day: testDate(2026, 5, 1), hour: 7, minutes: 30, subjectId: 1, subjectName: "数学")
        ]
        let useCase = GetReportsDataUseCase(
            subjectRepository: TestSubjectRepository([math, english]),
            sessionRepository: TestStudySessionRepository(sessions),
            clock: Clock(nowProvider: { reference })
        )

        let result = try await useCase.execute(reference: reference)

        XCTAssertEqual(result.daily.map(\.minutes), [30, 30, 0, 0, 15, 45, 90])
        XCTAssertEqual(result.weekly.last?.hours, 2)
        XCTAssertEqual(result.weekly.last?.minutes, 30)
        XCTAssertEqual(result.monthly.last?.totalHours, 3)
        XCTAssertEqual(result.bySubject.map(\.subjectName), ["数学", "英語"])
        XCTAssertEqual(result.bySubject.first?.hours, 6)
        XCTAssertEqual(result.bySubject.first?.minutes, 0)
        XCTAssertEqual(result.ratingAverages.today.ratedMinutes, 90)
        XCTAssertEqual(result.ratingAverages.today.average ?? 0, 4.333, accuracy: 0.01)
        XCTAssertEqual(result.streakDays, 3)
        XCTAssertEqual(result.bestStreak, 4)
    }

    func test_execute_returnsEmptyReportWhenNoSessionsExist() async throws {
        let reference = testDate(2026, 5, 6, hour: 20)
        let useCase = GetReportsDataUseCase(
            subjectRepository: TestSubjectRepository([Subject(id: 1, name: "数学", color: 1)]),
            sessionRepository: TestStudySessionRepository(),
            clock: Clock(nowProvider: { reference })
        )

        let result = try await useCase.execute(reference: reference)

        XCTAssertEqual(result.daily.count, 7)
        XCTAssertTrue(result.daily.allSatisfy { $0.minutes == 0 && $0.segments.isEmpty })
        XCTAssertTrue(result.bySubject.isEmpty)
        XCTAssertEqual(result.ratingAverages.today.ratedMinutes, 0)
        XCTAssertEqual(result.streakDays, 0)
        XCTAssertEqual(result.bestStreak, 0)
    }
}
