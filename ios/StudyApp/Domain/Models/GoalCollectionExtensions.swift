import Foundation

extension Sequence where Element == Goal {
    func latestActiveDailyGoal(for dayOfWeek: StudyWeekday) -> Goal? {
        filter { $0.type == .daily && $0.isActive && $0.deletedAt == nil && $0.dayOfWeek == dayOfWeek }
            .max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    func latestActiveWeeklyGoal() -> Goal? {
        filter { $0.type == .weekly && $0.isActive && $0.deletedAt == nil }
            .max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    func latestActiveDailyGoalsByWeekday() -> [StudyWeekday: Goal] {
        reduce(into: [StudyWeekday: Goal]()) { result, goal in
            guard goal.type == .daily, goal.isActive, goal.deletedAt == nil, let dayOfWeek = goal.dayOfWeek else {
                return
            }
            guard let current = result[dayOfWeek] else {
                result[dayOfWeek] = goal
                return
            }
            let isNewer = goal.updatedAt > current.updatedAt
                || (goal.updatedAt == current.updatedAt && goal.createdAt > current.createdAt)
            if isNewer {
                result[dayOfWeek] = goal
            }
        }
    }
}
