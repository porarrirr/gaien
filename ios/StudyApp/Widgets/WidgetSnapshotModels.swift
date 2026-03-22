import Foundation

enum StudyWidgetShared {
    static let appGroupIdentifier = "group.com.studyapp.ios.shared"
    static let snapshotKey = "studyWidgetSnapshot"
}

enum StudyWidgetSnapshotError: LocalizedError {
    case sharedDefaultsUnavailable

    var errorDescription: String? {
        switch self {
        case .sharedDefaultsUnavailable:
            return "共有ウィジェットストレージにアクセスできません。"
        }
    }
}

struct StudyWidgetExamSummary: Codable, Hashable, Identifiable {
    var id: String { "\(name)-\(epochDay)" }

    var name: String
    var epochDay: Int64
    var daysRemaining: Int

    var examDate: Date {
        studyWidgetDate(fromEpochDay: epochDay)
    }
}

struct StudyWidgetActivitySummary: Codable, Hashable, Identifiable {
    var id: String { "\(dayLabel)-\(isToday)" }

    var dayLabel: String
    var minutes: Int
    var isToday: Bool
}

struct StudyWidgetSnapshot: Codable, Hashable {
    var generatedAt: Int64
    var todayStudyMinutes: Int
    var todaySessionCount: Int
    var dailyGoalMinutes: Int?
    var weeklyGoalMinutes: Int?
    var weeklyStudyMinutes: Int
    var streakDays: Int
    var bestStreak: Int
    var upcomingExams: [StudyWidgetExamSummary]
    var weekActivity: [StudyWidgetActivitySummary]

    var todayProgress: Double {
        guard let dailyGoalMinutes, dailyGoalMinutes > 0 else { return 0 }
        return min(max(Double(todayStudyMinutes) / Double(dailyGoalMinutes), 0), 1)
    }

    var weeklyProgress: Double {
        guard let weeklyGoalMinutes, weeklyGoalMinutes > 0 else { return 0 }
        return min(max(Double(weeklyStudyMinutes) / Double(weeklyGoalMinutes), 0), 1)
    }

    var weekTotalMinutes: Int {
        weekActivity.reduce(0) { $0 + $1.minutes }
    }

    static func empty(referenceDate: Date = Date()) -> StudyWidgetSnapshot {
        StudyWidgetSnapshot(
            generatedAt: referenceDate.timeIntervalSince1970Milliseconds,
            todayStudyMinutes: 0,
            todaySessionCount: 0,
            dailyGoalMinutes: nil,
            weeklyGoalMinutes: nil,
            weeklyStudyMinutes: 0,
            streakDays: 0,
            bestStreak: 0,
            upcomingExams: [],
            weekActivity: buildWeekActivity(referenceDate: referenceDate, values: Array(repeating: 0, count: 7))
        )
    }

    static var placeholder: StudyWidgetSnapshot {
        let referenceDate = Date()
        let referenceDay = studyWidgetEpochDay(referenceDate)
        return StudyWidgetSnapshot(
            generatedAt: referenceDate.timeIntervalSince1970Milliseconds,
            todayStudyMinutes: 95,
            todaySessionCount: 3,
            dailyGoalMinutes: 120,
            weeklyGoalMinutes: 420,
            weeklyStudyMinutes: 285,
            streakDays: 6,
            bestStreak: 14,
            upcomingExams: [
                StudyWidgetExamSummary(name: "数学", epochDay: referenceDay + 3, daysRemaining: 3),
                StudyWidgetExamSummary(name: "英語", epochDay: referenceDay + 8, daysRemaining: 8)
            ],
            weekActivity: buildWeekActivity(referenceDate: referenceDate, values: [20, 35, 0, 50, 40, 65, 75])
        )
    }
}

enum StudyWidgetSnapshotStore {
    static func write(_ snapshot: StudyWidgetSnapshot) throws {
        let defaults = try sharedDefaults()
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: StudyWidgetShared.snapshotKey)
    }

    static func read() throws -> StudyWidgetSnapshot? {
        let defaults = try sharedDefaults()
        guard let data = defaults.data(forKey: StudyWidgetShared.snapshotKey) else {
            return nil
        }
        return try JSONDecoder().decode(StudyWidgetSnapshot.self, from: data)
    }

    private static func sharedDefaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: StudyWidgetShared.appGroupIdentifier) else {
            throw StudyWidgetSnapshotError.sharedDefaultsUnavailable
        }
        return defaults
    }
}

func studyWidgetDayLabel(for date: Date) -> String {
    switch Calendar.current.component(.weekday, from: date) {
    case 1: return "日"
    case 2: return "月"
    case 3: return "火"
    case 4: return "水"
    case 5: return "木"
    case 6: return "金"
    default: return "土"
    }
}

func studyWidgetDate(fromEpochDay epochDay: Int64) -> Date {
    let epochStart = Date(timeIntervalSince1970: 0)
    return Calendar.current.date(byAdding: .day, value: Int(epochDay), to: Calendar.current.startOfDay(for: epochStart))
        ?? Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
}

extension Int {
    var widgetDurationText: String {
        let hours = self / 60
        let minutes = self % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)時間\(minutes)分"
        }
        if hours > 0 {
            return "\(hours)時間"
        }
        return "\(minutes)分"
    }

    var widgetCompactDurationText: String {
        let hours = self / 60
        let minutes = self % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h\(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

extension Date {
    fileprivate var timeIntervalSince1970Milliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1_000).rounded())
    }
}

private func buildWeekActivity(referenceDate: Date, values: [Int]) -> [StudyWidgetActivitySummary] {
    let today = studyWidgetStartOfDay(referenceDate)
    return values.enumerated().compactMap { index, minutes in
        guard let date = Calendar.current.date(byAdding: .day, value: index - 6, to: today) else {
            return nil
        }
        return StudyWidgetActivitySummary(
            dayLabel: studyWidgetDayLabel(for: date),
            minutes: minutes,
            isToday: Calendar.current.isDate(date, inSameDayAs: today)
        )
    }
}

private func studyWidgetStartOfDay(_ date: Date) -> Date {
    Calendar.current.startOfDay(for: date)
}

private func studyWidgetEpochDay(_ date: Date) -> Int64 {
    let epochStart = Date(timeIntervalSince1970: 0)
    let startOfEpoch = Calendar.current.startOfDay(for: epochStart)
    let startOfDate = Calendar.current.startOfDay(for: date)
    return Int64(Calendar.current.dateComponents([.day], from: startOfEpoch, to: startOfDate).day ?? 0)
}
