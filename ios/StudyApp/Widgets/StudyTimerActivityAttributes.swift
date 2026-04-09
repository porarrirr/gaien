import Foundation
#if canImport(ActivityKit)
import ActivityKit

struct StudyTimerActivityAttributes: ActivityAttributes, Hashable {
    public struct ContentState: Codable, Hashable {
        var isRunning: Bool
        var startedAt: Int64?
        var accumulatedMilliseconds: Int64
        var todayCommittedMinutes: Int
        var dailyGoalMinutes: Int?
        var lastUpdatedAt: Int64

        var timerReferenceDate: Date? {
            guard let startedAt else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(startedAt - accumulatedMilliseconds) / 1_000)
        }
    }

    var subjectName: String
    var materialName: String
    var displayPreset: LiveActivityDisplayPreset
}
#endif
