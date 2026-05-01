import Foundation

struct TimetablePeriod: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var startMinute: Int
    var endMinute: Int
    var sortOrder: Int
    var isActive: Bool = true
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var timeRangeText: String {
        "\(Self.timeText(startMinute))-\(Self.timeText(endMinute))"
    }

    static func timeText(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    static var defaultPeriods: [TimetablePeriod] {
        [
            TimetablePeriod(name: "1限", startMinute: 9 * 60, endMinute: 10 * 60 + 30, sortOrder: 1),
            TimetablePeriod(name: "2限", startMinute: 10 * 60 + 40, endMinute: 12 * 60 + 10, sortOrder: 2),
            TimetablePeriod(name: "3限", startMinute: 13 * 60, endMinute: 14 * 60 + 30, sortOrder: 3),
            TimetablePeriod(name: "4限", startMinute: 14 * 60 + 40, endMinute: 16 * 60 + 10, sortOrder: 4),
            TimetablePeriod(name: "5限", startMinute: 16 * 60 + 20, endMinute: 17 * 60 + 50, sortOrder: 5),
            TimetablePeriod(name: "6限", startMinute: 18 * 60, endMinute: 19 * 60 + 30, sortOrder: 6),
            TimetablePeriod(name: "7限", startMinute: 19 * 60 + 40, endMinute: 21 * 60 + 10, sortOrder: 7)
        ]
    }
}

struct TimetableEntry: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var dayOfWeek: StudyWeekday
    var periodId: Int64
    var periodSyncId: String?
    var subjectName: String
    var courseName: String?
    var roomName: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?
}

struct TimetableLesson: Hashable {
    var entry: TimetableEntry
    var period: TimetablePeriod
    var dayOfWeek: StudyWeekday
    var date: Date
    var isCurrent: Bool

    var statusTitle: String {
        isCurrent ? "現在の授業" : "次の授業"
    }
}

extension StudyWeekday {
    static let timetableDays: [StudyWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
}
