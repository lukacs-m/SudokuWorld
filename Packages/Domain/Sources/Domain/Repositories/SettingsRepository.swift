public import Model

/// Player preferences. UserDefaults-backed, hence non-throwing.
public protocol SettingsRepository: Sendable {
    func gameSettings() async -> GameSettings
    func setGameSettings(_ settings: GameSettings) async
    func notificationPreferences() async -> NotificationPreferences
    func setNotificationPreferences(_ preferences: NotificationPreferences) async
}
