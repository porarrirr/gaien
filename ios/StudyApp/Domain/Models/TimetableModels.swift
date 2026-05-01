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
    var termId: Int64?
    var termSyncId: String?
    var dayOfWeek: StudyWeekday
    var periodId: Int64
    var periodSyncId: String?
    var subjectName: String
    var courseName: String?
    var roomName: String?
    var validFromDate: Int64?
    var validToDate: Int64?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?
}

struct TimetableTerm: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var startDate: Int64
    var endDate: Int64
    var isActive: Bool = true
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var startDateValue: Date {
        Date(epochDay: startDate)
    }

    var endDateValue: Date {
        Date(epochDay: endDate)
    }

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: startDateValue)) - \(formatter.string(from: endDateValue))"
    }

    func contains(_ date: Date) -> Bool {
        let day = date.startOfDay.epochDay
        return startDate <= day && day <= endDate
    }
}

struct TimetableReviewRecord: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var termId: Int64
    var termSyncId: String?
    var entryId: Int64
    var entrySyncId: String?
    var periodId: Int64
    var periodSyncId: String?
    var occurrenceDate: Int64
    var dayOfWeek: StudyWeekday
    var periodName: String
    var periodStartMinute: Int
    var periodEndMinute: Int
    var subjectName: String
    var courseName: String?
    var roomName: String?
    var isReviewed: Bool = false
    var note: String?
    var isExcluded: Bool = false
    var reviewedAt: Int64?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var occurrenceDateValue: Date {
        Date(epochDay: occurrenceDate)
    }

    var periodTimeRangeText: String {
        "\(TimetablePeriod.timeText(periodStartMinute))-\(TimetablePeriod.timeText(periodEndMinute))"
    }
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
