import Foundation
#if canImport(ActivityKit) && !LIVE_ACTIVITY_DISABLED
import ActivityKit
#endif

@MainActor
final class StudyLiveActivityController {
    private let persistence: PersistenceController
    private let logger: AppLogger

    init(persistence: PersistenceController, logger: AppLogger) {
        self.persistence = persistence
        self.logger = logger
    }

    func sync(activeTimer: TimerSnapshot?, preferences: AppPreferences, reason: String) async {
#if canImport(ActivityKit) && !LIVE_ACTIVITY_DISABLED
        guard #available(iOS 18.0, *) else { return }
        guard !Task.isCancelled else { return }

        do {
            guard preferences.liveActivityEnabled, let activeTimer else {
                try await endAllActivities(reason: reason)
                return
            }

            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                logger.log(
                    category: .app,
                    level: .warning,
                    message: "Live Activity sync skipped",
                    details: "reason=\(reason) authorized=false"
                )
                return
            }

            let context = try await buildContext(activeTimer: activeTimer, preferences: preferences)
            guard !Task.isCancelled else { return }
            try await upsertActivity(context: context, reason: reason)
        } catch {
            logger.log(
                category: .app,
                level: .error,
                message: "Live Activity sync failed",
                details: "reason=\(reason)",
                error: error
            )
        }
#endif
    }

#if canImport(ActivityKit) && !LIVE_ACTIVITY_DISABLED
    @available(iOS 18.0, *)
    private func buildContext(
        activeTimer: TimerSnapshot,
        preferences: AppPreferences
    ) async throws -> StudyLiveActivityContext {
        let now = Date()
        let todayStart = now.startOfDay.epochMilliseconds
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now.startOfDay) ?? now.startOfDay

        async let subjectTask = persistence.getSubjectById(activeTimer.subjectId)
        async let materialsTask = persistence.getAllMaterials()
        async let sessionsTask = persistence.getSessionsBetweenDates(start: todayStart, end: tomorrow.epochMilliseconds)
        async let dailyGoalTask = persistence.getActiveGoalByType(.daily)

        guard let subject = try await subjectTask else {
            throw ValidationError(message: "Live Activity の科目が見つかりません")
        }

        let materials = try await materialsTask
        let sessions = try await sessionsTask
        let dailyGoal = try await dailyGoalTask
        let materialName = materials.first(where: { $0.id == activeTimer.materialId })?.name ?? ""

        return StudyLiveActivityContext(
            attributes: StudyTimerActivityAttributes(
                subjectName: subject.name,
                materialName: materialName,
                displayPreset: preferences.liveActivityDisplayPreset
            ),
            state: StudyTimerActivityAttributes.ContentState(
                isRunning: activeTimer.isRunning,
                startedAt: activeTimer.startedAt,
                accumulatedMilliseconds: activeTimer.accumulatedMilliseconds,
                todayCommittedMinutes: sessions.reduce(0) { $0 + $1.durationMinutes },
                dailyGoalMinutes: dailyGoal?.targetMinutes,
                lastUpdatedAt: now.epochMilliseconds
            )
        )
    }

    @available(iOS 18.0, *)
    private func upsertActivity(context: StudyLiveActivityContext, reason: String) async throws {
        let activities = Activity<StudyTimerActivityAttributes>.activities

        if activities.count > 1 {
            for duplicate in activities.dropFirst() {
                let finalContent = ActivityContent(state: duplicate.content.state, staleDate: nil)
                await duplicate.end(finalContent, dismissalPolicy: .immediate)
            }
        }

        if let existing = activities.first {
            if existing.attributes != context.attributes {
                let finalContent = ActivityContent(state: existing.content.state, staleDate: nil)
                await existing.end(finalContent, dismissalPolicy: .immediate)
                _ = try Activity.request(
                    attributes: context.attributes,
                    content: ActivityContent(state: context.state, staleDate: nil),
                    pushType: nil
                )
                logger.log(
                    category: .app,
                    message: "Live Activity recreated",
                    details: "reason=\(reason) preset=\(context.attributes.displayPreset.rawValue)"
                )
            } else {
                await existing.update(ActivityContent(state: context.state, staleDate: nil))
                logger.log(
                    category: .app,
                    message: "Live Activity updated",
                    details: "reason=\(reason) running=\(context.state.isRunning)"
                )
            }
            return
        }

        _ = try Activity.request(
            attributes: context.attributes,
            content: ActivityContent(state: context.state, staleDate: nil),
            pushType: nil
        )
        logger.log(
            category: .app,
            message: "Live Activity started",
            details: "reason=\(reason) preset=\(context.attributes.displayPreset.rawValue)"
        )
    }

    @available(iOS 18.0, *)
    private func endAllActivities(reason: String) async throws {
        let activities = Activity<StudyTimerActivityAttributes>.activities
        guard !activities.isEmpty else { return }

        for activity in activities {
            let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }

        logger.log(
            category: .app,
            message: "Live Activity ended",
            details: "reason=\(reason) count=\(activities.count)"
        )
    }
#endif
}

#if canImport(ActivityKit) && !LIVE_ACTIVITY_DISABLED
@available(iOS 18.0, *)
private struct StudyLiveActivityContext {
    let attributes: StudyTimerActivityAttributes
    let state: StudyTimerActivityAttributes.ContentState
}
#endif
