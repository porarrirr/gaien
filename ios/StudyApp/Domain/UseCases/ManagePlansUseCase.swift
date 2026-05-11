import Foundation

struct ManagePlansUseCase {
    let repository: PlanRepository

    func createPlan(name: String, startDate: Date, endDate: Date, items: [PlanItem]) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError(message: "プラン名を入力してください")
        }
        guard startDate < endDate else {
            throw ValidationError(message: "開始日は終了日より前に設定してください")
        }
        guard !items.isEmpty else {
            throw ValidationError(message: "少なくとも1つの学習項目を追加してください")
        }
        try await repository.createPlan(
            StudyPlan(
                name: trimmed,
                startDate: Calendar.current.startOfDay(for: startDate).epochMilliseconds,
                endDate: Calendar.current.startOfDay(for: endDate).epochMilliseconds,
                isActive: true
            ),
            items: items
        )
    }
}
