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

    func startOfWeek(reference: Date? = nil) -> Int64 {
        let value = reference ?? now()
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: value)
        return (interval?.start ?? Calendar.current.startOfDay(for: value)).epochMilliseconds
    }
}

struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
