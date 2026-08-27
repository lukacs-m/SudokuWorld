import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Settings state: gameplay preferences, notifications, theme gating, and
/// Game Center status. Every mutation persists immediately.
@MainActor
@Observable
public final class SettingsViewModel {
    /// The Settings restore row's lifecycle. `PremiumGate` flips on its own
    /// through the entitlement stream when a restore actually recovers
    /// something; this only drives the row's feedback.
    public enum RestorePhase: Equatable {
        case idle
        case restoring
        case restored
        case nothingToRestore
        case failed
    }

    public private(set) var settings: GameSettings = .standard
    public private(set) var notifications: NotificationPreferences = .disabled
    public private(set) var authState: GameCenterAuthState = .unknown
    /// Set when the player enables reminders but the system denies permission.
    public private(set) var notificationsDenied = false
    public private(set) var isLoaded = false
    public private(set) var restorePhase: RestorePhase = .idle

    @ObservationIgnored @Injected(\.settingsRepository) private var settingsRepository
    @ObservationIgnored @Injected(\.restorePurchasesUseCase) private var restorePurchases
    @ObservationIgnored @Injected(\.updateRemindersUseCase) private var updateReminders
    @ObservationIgnored @Injected(\.observeGameCenterAuthUseCase) private var observeAuth
    @ObservationIgnored @Injected(\.authenticateGameCenterUseCase) private var authenticateGC

    public init() {}

    public func load() async {
        settings = await settingsRepository.gameSettings()
        notifications = await settingsRepository.notificationPreferences()
        isLoaded = true
    }

    public func observeAuthState() async {
        for await newState in observeAuth() {
            authState = newState
        }
    }

    public func signInToGameCenter() async {
        await authenticateGC()
    }

    /// Re-syncs App Store purchases with RevenueCat — the recovery path for
    /// a changed, reset, or additional device.
    public func restore() async {
        restorePhase = .restoring
        do {
            let entitlements = try await restorePurchases()
            restorePhase = entitlements.isPremium ? .restored : .nothingToRestore
        } catch {
            restorePhase = .failed
        }
    }

    // MARK: - Gameplay settings

    public func update(_ transform: (inout GameSettings) -> Void) {
        var updated = settings
        transform(&updated)
        settings = updated
        Task { [settingsRepository] in
            await settingsRepository.setGameSettings(updated)
        }
    }

    /// Selecting a premium theme without the entitlement returns false so the
    /// caller can raise the paywall instead.
    @discardableResult
    public func selectTheme(_ id: ThemeID, isPremium: Bool) -> Bool {
        if id.isPremium, !isPremium {
            return false
        }
        update { $0.theme = id }
        return true
    }

    // MARK: - Notifications

    public func updateNotifications(
        _ transform: (inout NotificationPreferences) -> Void,
        now: Date = Date(),
    ) async {
        var updated = notifications
        transform(&updated)
        notifications = updated
        await settingsRepository.setNotificationPreferences(updated)

        let authorized = await updateReminders(
            preferences: updated,
            copy: .fromCatalog(),
            now: now,
        )
        notificationsDenied = !authorized
            && (updated.dailyReminderEnabled || updated.streakReminderEnabled)
    }
}
