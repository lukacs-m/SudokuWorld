public import Model
public import Observation

/// How the game screen should begin.
public struct GameLaunch: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Start a fresh game with this configuration.
        case new(variant: SudokuVariant, difficulty: Difficulty, mode: GameMode)
        /// Resume the saved regular game.
        case resume
        /// Play (or resume) today's daily challenge.
        case daily
        /// Play a game counting toward this week's tournament.
        case weekly(variant: SudokuVariant, difficulty: Difficulty)
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}

/// Navigation destinations pushed onto the root stack.
public enum Route: Hashable, Sendable {
    case game(GameLaunch)
    case stats
    case events
    case settings
    case debug
}

/// The single navigation authority, injected through the environment.
@MainActor
@Observable
public final class Router {
    public var path: [Route] = []

    public init() {}

    public func push(_ route: Route) {
        path.append(route)
    }

    public func pop() {
        _ = path.popLast()
    }

    public func popToRoot() {
        path.removeAll()
    }
}
