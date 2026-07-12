public import Foundation

/// This week's tournament: a themed variant × difficulty rotating
/// deterministically by ISO week, scored cumulatively on a recurring
/// Game Center leaderboard.
public struct WeeklyTournament: Equatable, Sendable {
    /// ISO week key, e.g. "2026-W27".
    public let weekKey: String
    public let variant: SudokuVariant
    public let difficulty: Difficulty
    /// When the tournament closes (next ISO-week boundary, UTC).
    public let endsAt: Date
    /// The local player's accumulated points this week.
    public let points: Int
    /// How many qualifying wins contributed to `points`.
    public let gamesCounted: Int

    public init(
        weekKey: String,
        variant: SudokuVariant,
        difficulty: Difficulty,
        endsAt: Date,
        points: Int,
        gamesCounted: Int,
    ) {
        self.weekKey = weekKey
        self.variant = variant
        self.difficulty = difficulty
        self.endsAt = endsAt
        self.points = points
        self.gamesCounted = gamesCounted
    }
}
