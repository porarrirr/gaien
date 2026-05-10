import Foundation

struct ManageGoalsUseCase {
    let repository: GoalRepository

    func updateGoal(
        type: GoalType,
        targetMinutes: Int,
        dayOfWeek: StudyWeekday? = nil,
        weekStartDay: StudyWeekday = .monday
    ) async throws {
        let goals = try await repository.getAllGoals()
        switch type {
        case .daily:
            if let current = goals.first(where: {
                $0.type == .daily &&
                $0.isActive &&
                $0.deletedAt == nil &&
                $0.dayOfWeek == dayOfWeek
            }) {
                var updated = current
                updated.targetMinutes = targetMinutes
                updated.dayOfWeek = dayOfWeek
                updated.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(updated)
            } else {
                try await repository.insertGoal(
                    Goal(
                        type: .daily,
                        targetMinutes: targetMinutes,
                        dayOfWeek: dayOfWeek,
                        weekStartDay: weekStartDay,
                        isActive: true
                    )
                )
            }
        case .weekly:
            for goal in goals where goal.type == .weekly && goal.isActive && goal.deletedAt == nil {
                var inactive = goal
                inactive.isActive = false
                inactive.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(inactive)
            }

            if let current = goals.first(where: {
                $0.type == .weekly &&
                $0.isActive &&
                $0.deletedAt == nil
            }) {
                var updated = current
                updated.targetMinutes = targetMinutes
                updated.weekStartDay = weekStartDay
                updated.isActive = true
                updated.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(updated)
            } else {
                try await repository.insertGoal(
                    Goal(
                        type: .weekly,
                        targetMinutes: targetMinutes,
                        weekStartDay: weekStartDay,
                        isActive: true
                    )
                )
            }
        }
    }
}
