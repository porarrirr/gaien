import Foundation

struct Exam: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var date: Int64
    var note: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var dateValue: Date {
        Date(epochDay: date)
    }

    func daysRemaining(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: dateValue)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func isPast(from referenceDate: Date = Date()) -> Bool {
        daysRemaining(from: referenceDate) < 0
    }
}
