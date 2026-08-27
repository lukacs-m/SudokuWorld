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

    public init(kind: Kind) {
        self.kind = kind
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

/// The single navigation authority, injected through the environment.
@MainActor
@Observable
public final class Router {
    public var selectedTab: AppTab = .home
    public var game: GamePresentation?

    public init() {}

    public func play(_ launch: GameLaunch) {
        game = GamePresentation(launch: launch)
    }

    public func dismissGame() {
        game = nil
    }

    public func goHome() {
        game = nil
        selectedTab = .home
    }
}
