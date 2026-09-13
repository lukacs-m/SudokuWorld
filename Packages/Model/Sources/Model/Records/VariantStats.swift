public import Foundation

/// Aggregated results for one variant × difficulty cell of the stats matrix.
public struct VariantStats: Equatable, Sendable, Codable {
    public let variant: SudokuVariant
    public let difficulty: Difficulty
    public let played: Int
    public let won: Int
    public let lost: Int
    public let abandoned: Int
    public let currentWinStreak: Int
    public let bestWinStreak: Int
    public let fastestTime: TimeInterval?
    public let averageTime: TimeInterval?
    /// Wins with no mistakes and no hints (a reveal counts as a hint).
    public let perfectSolves: Int

    public var winRate: Double {
        played > 0 ? Double(won) / Double(played) : 0
    }

    public init(
        variant: SudokuVariant,
        difficulty: Difficulty,
        played: Int,
        won: Int,
        lost: Int,
        abandoned: Int,
        currentWinStreak: Int,
        bestWinStreak: Int,
        fastestTime: TimeInterval?,
        averageTime: TimeInterval?,
        perfectSolves: Int,
    ) {
        self.variant = variant
        self.difficulty = difficulty
        self.played = played
        self.won = won
        self.lost = lost
        self.abandoned = abandoned
        self.currentWinStreak = currentWinStreak
        self.bestWinStreak = bestWinStreak
        self.fastestTime = fastestTime
        self.averageTime = averageTime
        self.perfectSolves = perfectSolves
    }
}
