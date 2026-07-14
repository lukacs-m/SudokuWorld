/// Opt-in local notification preferences. Everything defaults to off — the
/// player explicitly enables reminders from Settings.
public struct NotificationPreferences: Equatable, Sendable, Codable {
    /// Remind about today's daily challenge.
    public var dailyReminderEnabled: Bool
    /// Warn in the evening when today's challenge would break the streak.
    public var streakReminderEnabled: Bool
    /// Local hour (0-23) for the daily reminder.
    public var reminderHour: Int

    public static let disabled = Self(
        dailyReminderEnabled: false,
        streakReminderEnabled: false,
        reminderHour: 9,
    )

    public init(dailyReminderEnabled: Bool, streakReminderEnabled: Bool, reminderHour: Int) {
        self.dailyReminderEnabled = dailyReminderEnabled
        self.streakReminderEnabled = streakReminderEnabled
        self.reminderHour = reminderHour
    }
}
