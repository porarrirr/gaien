import XCTest
@testable import StudyApp

final class ManagePlansUseCaseTests: XCTestCase {
    func test_createPlan_trimsNameNormalizesDatesAndDelegatesItems() async throws {
        let repository = TestPlanRepository()
        let useCase = ManagePlansUseCase(repository: repository)
        let start = testDate(2026, 5, 4, hour: 13)
        let end = testDate(2026, 5, 10, hour: 22)
        let item = PlanItem(planId: 0, subjectId: 1, dayOfWeek: .monday, targetMinutes: 30)

        try await useCase.createPlan(name: "  Midterm Plan  ", startDate: start, endDate: end, items: [item])

        let created = try XCTUnwrap(repository.createdPlans.single)
        XCTAssertEqual(created.0.name, "Midterm Plan")
        XCTAssertEqual(created.0.startDate, Calendar.current.startOfDay(for: start).epochMilliseconds)
        XCTAssertEqual(created.0.endDate, Calendar.current.startOfDay(for: end).epochMilliseconds)
        XCTAssertTrue(created.0.isActive)
        XCTAssertEqual(created.1, [item])
    }

    func test_createPlan_rejectsBlankNameInvalidRangeAndEmptyItems() async throws {
        let repository = TestPlanRepository()
        let useCase = ManagePlansUseCase(repository: repository)
        let item = PlanItem(planId: 0, subjectId: 1, dayOfWeek: .monday, targetMinutes: 30)

        try await assertValidation("プラン名を入力してください") {
            try await useCase.createPlan(name: " ", startDate: testDate(2026, 5, 4), endDate: testDate(2026, 5, 5), items: [item])
        }
        try await assertValidation("開始日は終了日より前に設定してください") {
            try await useCase.createPlan(name: "Plan", startDate: testDate(2026, 5, 5), endDate: testDate(2026, 5, 5), items: [item])
        }
        try await assertValidation("少なくとも1つの学習項目を追加してください") {
            try await useCase.createPlan(name: "Plan", startDate: testDate(2026, 5, 4), endDate: testDate(2026, 5, 5), items: [])
        }

        XCTAssertTrue(repository.createdPlans.isEmpty)
    }

    private func assertValidation(_ message: String, action: () async throws -> Void) async throws {
        do {
            try await action()
            XCTFail("Expected validation error: \(message)")
        } catch {
            XCTAssertEqual(error.localizedDescription, message)
        }
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? self[0] : nil
    }
}
