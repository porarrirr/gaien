import Foundation

// MARK: - Duration / number helpers

func durationString(milliseconds: Int64) -> String {
    let totalSeconds = Int(milliseconds / 1_000)
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

func parseDraftInt(_ value: String) -> Int {
    let normalized = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
    return Int(normalized.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}

// MARK: - Cached formatters

/// Central, cached date formatters. Each property exposes a shared instance
/// configured with `ja_JP` locale so we don't allocate a new `DateFormatter`
/// inside SwiftUI computed properties on every redraw.
enum StudyFormatters {
    private static func japanese(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter
    }

    /// "yyyy年M月" — month picker header.
    static let yearMonth = japanese("yyyy年M月")

    /// "yyyy年 M月" — variant with trailing space used in Materials history.
    static let yearMonthSpaced = japanese("yyyy年 M月")

    /// "yyyy年M月d日" — long date without weekday.
    static let yearMonthDay = japanese("yyyy年M月d日")

    /// "yyyy年M月d日（E）" — long date with weekday.
    static let yearMonthDayWithWeekday = japanese("yyyy年M月d日（E）")

    /// "yyyy年M月d日 (E)" — long date with weekday (half-width parens).
    static let yearMonthDayWithWeekdayHalf = japanese("yyyy年M月d日 (E)")

    /// "M月d日（E）" — short date with weekday (full-width parens).
    static let monthDayWithWeekday = japanese("M月d日（E）")

    /// "M月 d日（E）" — short date with spacing.
    static let monthDayWithWeekdaySpaced = japanese("M月 d日（E）")

    /// "M/d (E)" — compact date with weekday.
    static let shortDateWithWeekday = japanese("M/d (E)")

    /// "M/d" — very compact date.
    static let shortDate = japanese("M/d")

    /// "M/d HH:mm" — short date with time.
    static let shortDateTime = japanese("M/d HH:mm")

    /// "yyyy/MM/dd" — ISO-style date.
    static let slashDate = japanese("yyyy/MM/dd")

    /// "yyyy/MM/dd（E）" — ISO-style date with weekday.
    static let slashDateWithWeekday = japanese("yyyy/MM/dd（E）")

    /// "yyyy/M/d（E）" — ISO-style date with weekday (no zero padding).
    static let slashDateWithWeekdayLoose = japanese("yyyy/M/d（E）")

    /// "yyyy/MM/dd HH:mm" — timestamp.
    static let slashTimestamp = japanese("yyyy/MM/dd HH:mm")

    /// "yyyy/MM/dd (E)" — evaluation sheet header.
    static let slashDateWithWeekdayHalf = japanese("yyyy/MM/dd (E)")

    /// "MM/dd  HH:mm:ss" — log view timestamp (double-space to align).
    static let logTimestamp = japanese("MM/dd  HH:mm:ss")

    /// "M月" — month label for charts.
    static let monthOnly = japanese("M月")

    /// "HH:mm" — 24h time.
    static let clock = japanese("HH:mm")

    /// "H:mm" — 24h time without zero padding.
    static let clockLoose = japanese("H:mm")

    /// "HH:mm:ss" — 24h time with seconds.
    static let clockWithSeconds = japanese("HH:mm:ss")

    /// "yyyy年 M月 d日（E） H:mm" — exam datetime.
    static let examDateTime = japanese("yyyy年 M月 d日（E） H:mm")

    /// "yyyyMMdd-HHmmss" — filename-safe timestamp (used for local backups).
    static let fileSafeTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    /// Localized medium date without time, used for term date-range text.
    static let mediumDateJP: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
