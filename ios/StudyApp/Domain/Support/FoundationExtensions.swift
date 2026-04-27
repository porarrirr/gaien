import Foundation

extension Date {
    var epochMilliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1_000).rounded())
    }

    var epochDay: Int64 {
        let calendar = Calendar.current
        guard let epochStart = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: epochStart), to: calendar.startOfDay(for: self)).day ?? 0
        return Int64(days)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    init(epochMilliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(epochMilliseconds) / 1_000)
    }

    init(epochDay: Int64) {
        let calendar = Calendar.current
        guard let epochStart = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) else {
            self = Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
            return
        }
        self = calendar.date(byAdding: .day, value: Int(epochDay), to: calendar.startOfDay(for: epochStart))
            ?? Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
