import XCTest
@testable import StudyApp

final class ProblemReviewSchedulerTests: XCTestCase {
    // Use a fixed wall-clock moment (2023-11-14 22:13:20 UTC) so that any day-
    // rollover arithmetic is stable across locales. We always recompute the
    // expected value via `Calendar.current` so the test still works in CI
    // time zones that are not UTC.
    private let reviewedAt: Int64 = 1_700_000_000_000

    // MARK: - Rating .good

    func test_firstGoodReview_createsOneStreak_andThreeDayInterval() {
        let record = ProblemReviewScheduler.schedule(
            materialId: 10,
            materialSyncId: "sync-10",
            problemNumber: 3,
            rating: .good,
            reviewedAt: reviewedAt,
            previous: nil
        )

        XCTAssertEqual(record.rating, .good)
        XCTAssertEqual(record.consecutiveCorrectCount, 1)
        XCTAssertEqual(record.wrongCount, 0)
        XCTAssertEqual(record.problemId, "10-3")
        XCTAssertEqual(record.materialId, 10)
        XCTAssertEqual(record.materialSyncId, "sync-10")
        XCTAssertEqual(record.problemNumber, 3)
        XCTAssertEqual(record.reviewedAt, reviewedAt)
        XCTAssertEqual(record.createdAt, reviewedAt)
        XCTAssertEqual(record.updatedAt, reviewedAt)
        XCTAssertEqual(record.nextReviewDate, expectedNextReviewDate(from: reviewedAt, intervalDays: 3))
    }

    func test_secondConsecutiveGood_extendsIntervalToSevenDays() {
        let previous = makePrevious(consecutiveCorrect: 1, wrongCount: 0)

        let record = ProblemReviewScheduler.schedule(
            materialId: 10,
            materialSyncId: nil,
            problemNumber: 1,
            rating: .good,
            reviewedAt: reviewedAt,
            previous: previous
        )

        XCTAssertEqual(record.consecutiveCorrectCount, 2)
        XCTAssertEqual(record.wrongCount, 0)
        XCTAssertEqual(record.nextReviewDate, expectedNextReviewDate(from: reviewedAt, intervalDays: 7))
    }

    func test_thirdConsecutiveGood_usesFourteenDayInterval() {
        let previous = makePrevious(consecutiveCorrect: 2, wrongCount: 0)

        let record = ProblemReviewScheduler.schedule(
            materialId: 10,
            materialSyncId: nil,
            problemNumber: 1,
            rating: .good,
            reviewedAt: reviewedAt,
            previous: previous
        )

        XCTAssertEqual(record.consecutiveCorrectCount, 3)
        XCTAssertEqual(record.nextReviewDate, expectedNextReviewDate(from: reviewedAt, intervalDays: 14))
    }

    func test_manyConsecutiveGoods_keepsFourteenDayInterval() {
        let previous = makePrevious(consecutiveCorrect: 9, wrongCount: 2)

        let record = ProblemReviewScheduler.schedule(
            materialId: 10,
            materialSyncId: nil,
            problemNumber: 1,
            rating: .good,
            reviewedAt: reviewedAt,
            previous: previous
        )

        XCTAssertEqual(record.consecutiveCorrectCount, 10)
        XCTAssertEqual(record.wrongCount, 2, "Good rating must preserve previous wrongCount")
        XCTAssertEqual(record.nextReviewDate, expectedNextReviewDate(from: reviewedAt, intervalDays: 14))
    }

    // MARK: - Rating .again

    func test_againWithoutPrevious_resetsStreak_andSchedulesNextDay() {
        let record = ProblemReviewScheduler.schedule(
            materialId: 42,
            materialSyncId: "material-42",
            problemNumber: 7,
            rating: .again,
            reviewedAt: reviewedAt,
            previous: nil
        )

        XCTAssertEqual(record.rating, .again)
        XCTAssertEqual(record.consecutiveCorrectCount, 0)
        XCTAssertEqual(record.wrongCount, 1)
        XCTAssertEqual(record.problemId, "42-7")
        XCTAssertEqual(record.nextReviewDate, expectedNextReviewDate(from: reviewedAt, intervalDays: 1))
    }

    func test_againAfterStreak_resetsConsecutive_andIncrementsWrongCount() {
        let previous = makePrevious(consecutiveCorrect: 3, wrongCount: 2)

        let record = ProblemReviewScheduler.schedule(
            materialId: 42,
            materialSyncId: nil,
            problemNumber: 7,
            rating: .again,
            reviewedAt: reviewedAt,
            previous: previous
        )

        XCTAssertEqual(record.consecutiveCorrectCount, 0)
        XCTAssertEqual(record.wrongCount, 3)
        XCTAssertEqual(record.nextReviewDate, expectedNextReviewDate(from: reviewedAt, intervalDays: 1))
    }

    // MARK: - nextReviewDate normalisation

    func test_nextReviewDate_isNormalisedToStartOfDay() {
        // Pick a reviewedAt that is clearly mid-day regardless of local timezone.
        let calendar = Calendar.current
        let midDay = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: calendar.startOfDay(for: Date()))!
        let midDayMillis = midDay.epochMilliseconds

        let record = ProblemReviewScheduler.schedule(
            materialId: 1,
            materialSyncId: nil,
            problemNumber: 1,
            rating: .again,
            reviewedAt: midDayMillis,
            previous: nil
        )

        let nextReviewDate = Date(epochMilliseconds: record.nextReviewDate)
        let components = calendar.dateComponents([.hour, .minute, .second], from: nextReviewDate)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: - Helpers

    private func makePrevious(consecutiveCorrect: Int, wrongCount: Int) -> ProblemReviewRecord {
        ProblemReviewRecord(
            problemId: "10-1",
            materialId: 10,
            materialSyncId: nil,
            problemNumber: 1,
            reviewedAt: reviewedAt - 86_400_000,
            rating: consecutiveCorrect > 0 ? .good : .again,
            nextReviewDate: reviewedAt,
            consecutiveCorrectCount: consecutiveCorrect,
            wrongCount: wrongCount
        )
    }

    private func expectedNextReviewDate(from reviewedAt: Int64, intervalDays: Int) -> Int64 {
        let calendar = Calendar.current
        let reviewDate = Date(epochMilliseconds: reviewedAt)
        let nextDay = calendar.date(
            byAdding: .day,
            value: intervalDays,
            to: calendar.startOfDay(for: reviewDate)
        ) ?? reviewDate
        return calendar.startOfDay(for: nextDay).epochMilliseconds
    }
}
