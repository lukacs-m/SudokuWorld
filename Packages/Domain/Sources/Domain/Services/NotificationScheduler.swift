public import Model

/// Pre-localized notification texts, built by Presentation so every
/// user-facing string lives in the one string catalog.
public struct ReminderCopy: Equatable, Sendable {
    public let dailyTitle: String
    public let dailyBody: String
    public let streakTitle: String
    public let streakBody: String

    public init(dailyTitle: String, dailyBody: String, streakTitle: String, streakBody: String) {
        self.dailyTitle = dailyTitle
        self.dailyBody = dailyBody
        self.streakTitle = streakTitle
        self.streakBody = streakBody
    }
}

/// Local-notification abstraction over UserNotifications.
public protocol NotificationScheduler: Sendable {
    /// Requests permission when needed. Returns whether notifications are
    /// authorized afterward.
    func requestAuthorization() async -> Bool
    /// Replaces all pending reminders according to the preferences: a daily
    /// reminder at the preferred hour, plus an evening streak-saver when
    /// `streakAtRisk` is set.
    func updateReminders(
        preferences: NotificationPreferences,
        copy: ReminderCopy,
        streakAtRisk: Bool,
    ) async
    func cancelAllReminders() async
}
