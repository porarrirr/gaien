import Foundation

/// Orchestrates notification permission, daily reminder scheduling, and
/// timetable review overdue reminders based on the stored preferences.
/// Extracted from `StudyAppContainer` to keep that class focused on
/// DI + data-version bus + sync proxy responsibilities.
@MainActor
final class ReminderCoordinator {
    private let scheduler: ReminderScheduler
    private let persistence: PersistenceController
    private let logger: AppLogger

    init(scheduler: ReminderScheduler, persistence: PersistenceController, logger: AppLogger) {
        self.scheduler = scheduler
        self.persistence = persistence
        self.logger = logger
    }

    /// Enables or disables the daily study reminder. Returns the updated flag
    /// alongside an optional user-facing error message. The caller is expected
    /// to persist the boolean into `AppPreferences`.
    func setEnabled(_ enabled: Bool, preferences: AppPreferences) async -> Result<Bool, ReminderError> {
        if enabled {
            do {
                let granted = try await scheduler.requestAuthorizationIfNeeded()
                guard granted else {
                    return .failure(.permissionDenied)
                }
                try await scheduler.scheduleDailyReminder(hour: preferences.reminderHour, minute: preferences.reminderMinute)
                let overdueCount = try await persistence.overdueTimetableReviewCount()
                try await scheduler.scheduleTimetableReviewReminder(overdueCount: overdueCount)
                return .success(true)
            } catch {
                logger.log(category: .app, level: .error, message: "Failed to enable reminder", error: error)
                return .failure(.scheduling(error))
            }
        } else {
            scheduler.cancelReminder()
            return .success(false)
        }
    }

    /// Updates the daily reminder time if the reminder is already enabled. The
    /// caller is expected to validate the (hour, minute) range and persist them.
    func applyReminderTime(hour: Int, minute: Int, preferences: AppPreferences) async -> Result<Void, Error> {
        guard preferences.reminderEnabled else { return .success(()) }
        do {
            try await scheduler.scheduleDailyReminder(hour: hour, minute: minute)
            let overdueCount = try await persistence.overdueTimetableReviewCount()
            try await scheduler.scheduleTimetableReviewReminder(overdueCount: overdueCount)
            return .success(())
        } catch {
            logger.log(category: .app, level: .error, message: "Failed to reschedule reminder", error: error)
            return .failure(error)
        }
    }

    /// Refreshes the timetable review overdue reminder. Should be called after
    /// data changes that could affect overdue counts.
    func refreshTimetableReviewReminder() async throws {
        let overdueCount = try await persistence.overdueTimetableReviewCount()
        try await scheduler.scheduleTimetableReviewReminder(overdueCount: overdueCount)
    }
}

enum ReminderError: LocalizedError {
    case permissionDenied
    case scheduling(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "通知の許可が必要です"
        case .scheduling(let error):
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
