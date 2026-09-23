public import Foundation
public import Model
public import Observation

/// How the game screen should begin.
public struct GameLaunch: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Start a fresh game with this configuration.
        case new(variant: SudokuVariant, difficulty: Difficulty, mode: GameMode)
        /// Resume the saved regular game.
        case resume
        /// Play (or resume) one slot of a day's daily lineup.
        case daily(dateKey: String, variant: SudokuVariant, difficulty: Difficulty)
        /// Play a game counting toward this week's tournament.
        case weekly(variant: SudokuVariant, difficulty: Difficulty)
    }

    public let kind: Kind

    /// A `.new` launch is normalised to the variant's nearest offered tier, so
    /// no entry point (play again on a pre-update save, debug menu, launch
    /// hook) can start a fresh game on a hidden tier.
    public init(kind: Kind) {
        guard case let .new(variant, difficulty, mode) = kind else {
            self.kind = kind
            return
        }
        self.kind = .new(
            variant: variant,
            difficulty: variant.nearestOfferedDifficulty(to: difficulty),
            mode: mode,
        )
    }
}

/// The four root tabs.
public enum AppTab: Hashable, Sendable {
    case home
    case events
    case stats
    case settings
}

/// A presented game. The fresh `id` per presentation guarantees the cover
/// rebuilds even when the same configuration is launched twice in a row.
public struct GamePresentation: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let launch: GameLaunch

    public init(launch: GameLaunch) {
        id = UUID()
        self.launch = launch
    }
}

/// The app-level router, injected through the environment: the selected
/// tab and the app's modals. Each tab's stack has its own `Router` (see
/// `Routes.swift`); this one owns what sits above the stacks.
@MainActor
@Observable
public final class AppRouter {
    public var selectedTab: AppTab = .home
    public var presentedSheet: SheetDestination?
    public var presentedFullScreen: FullScreenDestination?

    public init() {}

    /// A fresh `GamePresentation` per call, so the cover rebuilds even when
    /// the same configuration is launched twice in a row.
    public func play(_ launch: GameLaunch) {
        presentedFullScreen = .game(GamePresentation(launch: launch))
    }

    public func dismissGame() {
        presentedFullScreen = nil
    }

    public func goHome() {
        presentedFullScreen = nil
        selectedTab = .home
    }
}
