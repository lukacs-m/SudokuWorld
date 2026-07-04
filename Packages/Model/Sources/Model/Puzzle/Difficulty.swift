/// Puzzle difficulty, graded by the solving techniques a puzzle requires —
/// never by clue count alone. Raw values are the canonical slugs used in
/// Game Center identifiers.
public enum Difficulty: String, CaseIterable, Equatable, Sendable, Codable {
    case beginner
    case easy
    case medium
    case hard
    case expert
    case master

    /// Stable identifier used in leaderboard IDs and persistence.
    public var slug: String {
        rawValue
    }

    /// Monotonic rank for ordering and nearest-difficulty fallbacks.
    public var rank: Int {
        switch self {
        case .beginner: 0
        case .easy: 1
        case .medium: 2
        case .hard: 3
        case .expert: 4
        case .master: 5
        }
    }
}

extension Difficulty: Comparable {
    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rank < rhs.rank
    }
}
