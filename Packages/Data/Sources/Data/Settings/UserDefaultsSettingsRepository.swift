public import Domain
import Foundation
public import Model

/// UserDefaults-backed preferences, isolated behind an actor. Values are
/// stored as JSON so the settings shape can grow without migration fuss.
public actor UserDefaultsSettingsRepository: SettingsRepository {
    private enum Keys {
        static let gameSettings = "settings.game"
        static let notifications = "settings.notifications"
    }

    private let defaults: UserDefaults

    public init(suiteName: String? = nil) {
        defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    public func gameSettings() async -> GameSettings {
        guard let data = defaults.data(forKey: Keys.gameSettings),
              let settings = try? JSONDecoder().decode(GameSettings.self, from: data)
        else { return .standard }
        return settings
    }

    public func setGameSettings(_ settings: GameSettings) async {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.gameSettings)
        }
    }

    public func notificationPreferences() async -> NotificationPreferences {
        guard let data = defaults.data(forKey: Keys.notifications),
              let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return .disabled }
        return preferences
    }

    public func setNotificationPreferences(_ preferences: NotificationPreferences) async {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: Keys.notifications)
        }
    }
}
