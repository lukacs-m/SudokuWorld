public import Foundation

/// One finished game. Records are the source of truth for statistics, streaks,
/// leaderboard submissions, and achievement progress.
public struct GameRecord: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let variant: SudokuVariant
    public let difficulty: Difficulty
    public let mode: GameMode
    public let outcome: GameOutcome
    public let context: GameContext
    public let duration: TimeInterval
    public let mistakes: Int
    public let hintsUsed: Int
    public let usedReveal: Bool
    /// Tournament points earned by this game (0 outside weekly context).
    public let points: Int
    public let startedAt: Date
    public let finishedAt: Date

    public init(
        id: UUID,
        variant: SudokuVariant,
        difficulty: Difficulty,
        mode: GameMode,
        outcome: GameOutcome,
        context: GameContext,
        duration: TimeInterval,
        mistakes: Int,
        hintsUsed: Int,
        usedReveal: Bool,
        points: Int,
        startedAt: Date,
        finishedAt: Date,
    ) {
        self.id = id
        self.variant = variant
        self.difficulty = difficulty
        self.mode = mode
        self.outcome = outcome
        self.context = context
        self.duration = duration
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.usedReveal = usedReveal
        self.points = points
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}
