import XCTest
@testable import StudyApp

/// Tests the goal-selection rules used throughout the app (home dashboard,
/// widget snapshot, reports). "Latest wins" here must stay deterministic so
/// the widget and home screen don't disagree about which goal is active.
final class GoalCollectionExtensionsTests: XCTestCase {

    func test_latestActiveDailyGoal_returnsMostRecentForWeekday() {
        let older = makeDaily(weekday: .monday, target: 60, createdAt: 0, updatedAt: 1_000)
        let newer = makeDaily(weekday: .monday, target: 90, createdAt: 0, updatedAt: 2_000)

        let result = [older, newer].latestActiveDailyGoal(for: .monday)

        XCTAssertEqual(result?.targetMinutes, 90)
    }

    func test_latestActiveDailyGoal_tieBreaksOnCreatedAt() {
        // Same updatedAt: the one created later is newer (monotonic clock
        // assumption used in the extension).
        let earlier = makeDaily(weekday: .monday, target: 60, createdAt: 100, updatedAt: 1_000)
        let later = makeDaily(weekday: .monday, target: 90, createdAt: 200, updatedAt: 1_000)

        let result = [earlier, later].latestActiveDailyGoal(for: .monday)

        XCTAssertEqual(result?.targetMinutes, 90)
    }

    func test_latestActiveDailyGoal_ignoresInactiveAndDeleted() {
        let deleted = makeDaily(
            weekday: .monday,
            target: 120,
            createdAt: 0,
            updatedAt: 3_000,
            deletedAt: 3_500
        )
        let inactive = makeDaily(
            weekday: .monday,
            target: 150,
            createdAt: 0,
            updatedAt: 4_000,
            isActive: false
        )
        let active = makeDaily(weekday: .monday, target: 60, createdAt: 0, updatedAt: 1_000)

        let result = [deleted, inactive, active].latestActiveDailyGoal(for: .monday)

        XCTAssertEqual(result?.targetMinutes, 60)
    }

    func test_latestActiveDailyGoal_isNilWhenWeekdayHasNoMatch() {
        let wednesday = makeDaily(weekday: .wednesday, target: 60, createdAt: 0, updatedAt: 1_000)
        let result = [wednesday].latestActiveDailyGoal(for: .monday)

        XCTAssertNil(result)
    }

    func test_latestActiveWeeklyGoal_picksNewest() {
        let older = Goal(
            id: 0,
            syncId: "w1",
            type: .weekly,
            targetMinutes: 300,
            dayOfWeek: nil,
            weekStartDay: .monday,
            isActive: true,
            createdAt: 0,
            updatedAt: 1_000
        )
        let newer = Goal(
            id: 0,
            syncId: "w2",
            type: .weekly,
            targetMinutes: 420,
            dayOfWeek: nil,
            weekStartDay: .monday,
            isActive: true,
            createdAt: 0,
            updatedAt: 2_000
        )

        let result = [older, newer].latestActiveWeeklyGoal()

        XCTAssertEqual(result?.targetMinutes, 420)
    }

    func test_latestActiveDailyGoalsByWeekday_groupsByDay() {
        let monday = makeDaily(weekday: .monday, target: 60, createdAt: 0, updatedAt: 1_000)
        let tuesday = makeDaily(weekday: .tuesday, target: 30, createdAt: 0, updatedAt: 1_000)
        let tuesdayNewer = makeDaily(weekday: .tuesday, target: 45, createdAt: 0, updatedAt: 2_000)

        let result = [monday, tuesday, tuesdayNewer].latestActiveDailyGoalsByWeekday()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[.monday]?.targetMinutes, 60)
        XCTAssertEqual(result[.tuesday]?.targetMinutes, 45)
    }

    // MARK: - Helpers

    private func makeDaily(
        weekday: StudyWeekday,
        target: Int,
        createdAt: Int64,
        updatedAt: Int64,
        isActive: Bool = true,
        deletedAt: Int64? = nil
    ) -> Goal {
        Goal(
            id: 0,
            syncId: "d-\(weekday.rawValue)-\(target)",
            type: .daily,
            targetMinutes: target,
            dayOfWeek: weekday,
            weekStartDay: .monday,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
