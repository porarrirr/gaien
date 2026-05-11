import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Bridges the running app's data layer to the widget's shared snapshot file.
///
/// Responsibility is kept narrow: fetch the minimum data from the repository
/// (bounded recent sessions + goal list + upcoming exams + distinct study
/// days), hand it to `StudyWidgetSnapshotComputer`, and persist the result.
@MainActor
final class WidgetSnapshotSync {
    private weak var container: StudyAppContainer?
    private var refreshTask: Task<Void, Never>?

    /// How far back we pull sessions for today/week totals and the 7-day
    /// activity strip. 14 days is comfortably wider than a calendar week
    /// while keeping the fetch bounded for users with lots of history.
    private static let recentSessionsLookbackDays = 14

    init(container: StudyAppContainer) {
        self.container = container
    }

    func scheduleRefresh(reason: String) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.refresh(reason: reason)
            } catch is CancellationError {
                return
            } catch {
                self.container?.logger.log(
                    category: .app,
                    level: .warning,
                    message: "Widget snapshot refresh failed",
                    details: "reason=\(reason)",
                    error: error
                )
            }
        }
    }

    private func refresh(reason: String) async throws {
        guard let container else { return }
        let inputs = try await loadInputs(container: container)
        // Computation is pure; run it off the main actor so very large
        // `studyDayEpochDays` arrays don't stall the UI.
        let snapshot = await Task.detached(priority: .utility) {
            StudyWidgetSnapshotComputer.compute(inputs)
        }.value
        try StudyWidgetSnapshotStore.write(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        container.logger.log(
            category: .app,
            message: "Widget snapshot refreshed",
            details: "reason=\(reason)"
        )
    }

    private func loadInputs(container: StudyAppContainer) async throws -> StudyWidgetSnapshotComputer.Inputs {
        let now = container.clock.now()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let lookbackStart = calendar.date(
            byAdding: .day,
            value: -Self.recentSessionsLookbackDays,
            to: today
        ) ?? today
        let lookbackEnd = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        async let recentSessionsTask = container.persistence.getSessionsBetweenDates(
            start: lookbackStart.epochMilliseconds,
            end: lookbackEnd.epochMilliseconds
        )
        async let goalsTask = container.persistence.getAllGoals()
        async let examsTask = container.persistence.getUpcomingExams(now: now)
        async let studyDaysTask = container.persistence.getDistinctStudyDays()

        return StudyWidgetSnapshotComputer.Inputs(
            recentSessions: try await recentSessionsTask,
            goals: try await goalsTask,
            upcomingExams: try await examsTask,
            studyDayEpochDays: try await studyDaysTask,
            referenceDate: now,
            calendar: calendar
        )
    }
}
