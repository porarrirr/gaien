import XCTest
@testable import StudyApp

final class ManageGoalsUseCaseTests: XCTestCase {
    func test_updateGoal_insertsDailyGoalWhenWeekdayHasNoActiveGoal() async throws {
        let repository = TestGoalRepository()
        let useCase = ManageGoalsUseCase(repository: repository)

        try await useCase.updateGoal(type: .daily, targetMinutes: 45, dayOfWeek: .tuesday)

        let inserted = try XCTUnwrap(repository.insertedGoals.single)
        XCTAssertEqual(inserted.type, .daily)
        XCTAssertEqual(inserted.targetMinutes, 45)
        XCTAssertEqual(inserted.dayOfWeek, .tuesday)
        XCTAssertTrue(inserted.isActive)
    }

    func test_updateGoal_updatesExistingDailyGoalForMatchingWeekday() async throws {
        let current = Goal(id: 7, type: .daily, targetMinutes: 30, dayOfWeek: .monday, isActive: true)
        let repository = TestGoalRepository([current])
        let useCase = ManageGoalsUseCase(repository: repository)

        try await useCase.updateGoal(type: .daily, targetMinutes: 80, dayOfWeek: .monday)

        XCTAssertTrue(repository.insertedGoals.isEmpty)
        let updated = try XCTUnwrap(repository.updatedGoals.single)
        XCTAssertEqual(updated.id, 7)
        XCTAssertEqual(updated.targetMinutes, 80)
        XCTAssertEqual(updated.dayOfWeek, .monday)
    }

    func test_updateGoal_replacesActiveWeeklyGoalAndDeactivatesOtherWeeklyGoals() async throws {
        let first = Goal(id: 1, type: .weekly, targetMinutes: 300, isActive: true)
        let second = Goal(id: 2, type: .weekly, targetMinutes: 360, isActive: true)
        let repository = TestGoalRepository([first, second])
        let useCase = ManageGoalsUseCase(repository: repository)

        try await useCase.updateGoal(type: .weekly, targetMinutes: 420, weekStartDay: .sunday)

        XCTAssertTrue(repository.insertedGoals.isEmpty)
        XCTAssertEqual(repository.updatedGoals.filter { $0.type == .weekly && !$0.isActive }.map(\.id).sorted(), [1, 2])
        let activated = repository.updatedGoals.last
        XCTAssertEqual(activated?.id, 1)
        XCTAssertEqual(activated?.targetMinutes, 420)
        XCTAssertEqual(activated?.weekStartDay, .sunday)
        XCTAssertEqual(activated?.isActive, true)
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? self[0] : nil
    }
}
