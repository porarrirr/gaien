import Foundation

struct Clock {
    func now() -> Date {
        Date()
    }

    func startOfToday(reference: Date = Date()) -> Int64 {
        Calendar.current.startOfDay(for: reference).epochMilliseconds
    }

    func startOfWeek(reference: Date = Date()) -> Int64 {
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: reference)
        return (interval?.start ?? Calendar.current.startOfDay(for: reference)).epochMilliseconds
    }
}

struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
