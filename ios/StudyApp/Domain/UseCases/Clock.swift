import Foundation

struct Clock {
    private let nowProvider: () -> Date

    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
    }

    func now() -> Date {
        nowProvider()
    }

    func startOfToday(reference: Date? = nil) -> Int64 {
        Calendar.current.startOfDay(for: reference ?? now()).epochMilliseconds
    }

    func startOfWeek(reference: Date? = nil, weekStartDay: StudyWeekday = .monday) -> Int64 {
        let value = reference ?? now()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: value)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceStart = (weekday - weekStartDay.calendarWeekday + 7) % 7
        return (calendar.date(byAdding: .day, value: -daysSinceStart, to: today) ?? today).epochMilliseconds
    }
}

struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
