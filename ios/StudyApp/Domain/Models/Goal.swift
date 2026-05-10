import Foundation

struct Goal: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var type: GoalType
    var targetMinutes: Int
    var dayOfWeek: StudyWeekday?
    var weekStartDay: StudyWeekday = .monday
    var isActive: Bool = true
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var targetFormatted: String {
        Goal.format(minutes: targetMinutes)
    }

    static func format(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 {
            return "\(hours)時間\(remainder)分"
        }
        if hours > 0 {
            return "\(hours)時間"
        }
        return "\(remainder)分"
    }
}
