import Foundation

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
