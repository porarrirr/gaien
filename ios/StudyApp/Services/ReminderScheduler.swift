import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler {
    static let notificationIdentifier = "studyapp.daily.reminder"

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

    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
    }
}
