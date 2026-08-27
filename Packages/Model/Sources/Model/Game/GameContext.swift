/// What a game counts toward. Daily and weekly games feed the events system
/// and their dedicated leaderboards; regular games feed the standard boards.
public enum GameContext: Hashable, Sendable, Codable {
    case regular
    case daily(dateKey: String, variant: SudokuVariant)
    case weekly(weekKey: String)

    /// Stable persistence key; at most one saved game exists per key.
    public var contextKey: String {
        switch self {
        case .regular: "main"
        case let .daily(dateKey, variant): "daily:\(dateKey):\(variant.slug)"
        case let .weekly(weekKey): "weekly:\(weekKey)"
        }
    }

    public var dailyDateKey: String? {
        if case let .daily(dateKey, _) = self {
            return dateKey
        }
        return nil
    }

    public var dailyVariant: SudokuVariant? {
        if case let .daily(_, variant) = self {
            return variant
        }
        return nil
    }

    public var weekKey: String? {
        if case let .weekly(weekKey) = self {
            return weekKey
        }
        return nil
    }
}
