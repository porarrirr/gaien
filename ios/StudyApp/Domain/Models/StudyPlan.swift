import Foundation

struct StudyPlan: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var startDate: Int64
    var endDate: Int64
    var isActive: Bool
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var startDateValue: Date {
        Date(epochMilliseconds: startDate)
    }

    var endDateValue: Date {
        Date(epochMilliseconds: endDate)
    }
}

struct PlanItem: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var planId: Int64
    var planSyncId: String?
    var subjectId: Int64
    var subjectSyncId: String?
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int = 0
    var timeSlot: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?
}
