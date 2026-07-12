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
    public private(set) var themeID: ThemeID = .classicBlue

    @ObservationIgnored
    @Injected(\.settingsRepository) private var settingsRepository

    public init() {}

    /// Resolves the drawable palette for the current color scheme.
    public func theme(for scheme: ColorScheme) -> Theme {
        ThemePalettes.palette(for: themeID, scheme: scheme)
    }

    /// Loads the persisted selection (call once at launch).
    public func load() async {
        themeID = await settingsRepository.gameSettings().theme
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
}
