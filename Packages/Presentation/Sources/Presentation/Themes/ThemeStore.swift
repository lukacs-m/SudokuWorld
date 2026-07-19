import DI
import Domain
public import Model
public import Observation
public import SwiftUI

/// App-wide theme selection, injected through the SwiftUI environment.
/// Selection persists as part of `GameSettings`; premium gating happens in
/// the theme picker (which knows entitlements), not here.
@MainActor
@Observable
public final class ThemeStore {
    public private(set) var themeID: ThemeID = .warmPaper
    public private(set) var appearance: AppearancePreference = .system

    @ObservationIgnored
    @Injected(\.settingsRepository) private var settingsRepository

    public init() {}

    /// Resolves the drawable palette for the current color scheme.
    public func theme(for scheme: ColorScheme) -> Theme {
        ThemePalettes.palette(for: themeID, scheme: scheme)
    }

    /// The scheme override to apply at the root (`nil` follows the system).
    public var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Loads the persisted selection (call once at launch).
    public func load() async {
        let settings = await settingsRepository.gameSettings()
        themeID = settings.theme
        appearance = settings.appearance ?? .system
    }

    public func select(_ id: ThemeID) {
        guard id != themeID else { return }
        themeID = id
        Task { [settingsRepository] in
            var settings = await settingsRepository.gameSettings()
            settings.theme = id
            await settingsRepository.setGameSettings(settings)
        }
    }

    public func selectAppearance(_ preference: AppearancePreference) {
        guard preference != appearance else { return }
        appearance = preference
        Task { [settingsRepository] in
            var settings = await settingsRepository.gameSettings()
            settings.appearance = preference
            await settingsRepository.setGameSettings(settings)
        }
    }
}
