import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler {
    static let notificationIdentifier = "studyapp.daily.reminder"
    static let timetableReviewNotificationIdentifier = "studyapp.timetable.review.overdue"

    private let center: UNUserNotificationCenter

    init() {
        self.center = .current()
    }

    init(center: UNUserNotificationCenter) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "学習時間です！"
        content.body = "今日の学習を始めましょう"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        try await center.add(request)
    }

    func scheduleTimetableReviewReminder(overdueCount: Int) async throws {
        center.removePendingNotificationRequests(withIdentifiers: [Self.timetableReviewNotificationIdentifier])
        guard overdueCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "授業の復習が残っています"
        content.body = "48時間を超えた未復習の授業が\(overdueCount)件あります。時間割で確認しましょう。"
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: Self.timetableReviewNotificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        try await center.add(request)
    }

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier, Self.timetableReviewNotificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier, Self.timetableReviewNotificationIdentifier])
    }
}
