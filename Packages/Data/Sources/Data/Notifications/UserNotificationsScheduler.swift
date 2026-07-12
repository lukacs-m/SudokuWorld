public import Domain
import Foundation
public import Model
import UserNotifications

/// UserNotifications adapter for the opt-in reminders. All copy arrives
/// pre-localized (`ReminderCopy`) so strings live in Presentation's catalog.
public struct UserNotificationsScheduler: NotificationScheduler {
    private static let dailyID = "reminder.daily"
    private static let streakID = "reminder.streak"
    /// Evening hour for the streak-saver warning.
    private static let streakReminderHour = 20

    public init() {}

    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await (try? center.requestAuthorization(options: [.alert, .sound, .badge]))
                ?? false
        @unknown default:
            return false
        }
    }

    public func updateReminders(
        preferences: NotificationPreferences,
        copy: ReminderCopy,
        streakAtRisk: Bool,
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyID, Self.streakID])

        if preferences.dailyReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = copy.dailyTitle
            content.body = copy.dailyBody
            content.sound = .default

            var trigger = DateComponents()
            trigger.hour = min(max(preferences.reminderHour, 0), 23)
            try? await center.add(UNNotificationRequest(
                identifier: Self.dailyID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true),
            ))
        }

        if preferences.streakReminderEnabled, streakAtRisk {
            let content = UNMutableNotificationContent()
            content.title = copy.streakTitle
            content.body = copy.streakBody
            content.sound = .default

            var trigger = DateComponents()
            trigger.hour = Self.streakReminderHour
            // One-shot: fires at the next 20:00, i.e. tonight — after that the
            // streak either survived (next update reschedules) or broke.
            try? await center.add(UNNotificationRequest(
                identifier: Self.streakID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: false),
            ))
        }
    }

    public func cancelAllReminders() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyID, Self.streakID])
    }
}
