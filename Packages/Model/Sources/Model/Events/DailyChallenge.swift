public import Foundation

/// Today's shared puzzle: generated from a date-derived seed so every player
/// worldwide plays the identical board.
public struct DailyChallenge: Equatable, Sendable {
    /// UTC calendar key, e.g. "2026-07-04".
    public let dateKey: String
    /// When this challenge rotates out (next UTC midnight).
    public let endsAt: Date
    public let puzzle: PuzzleDefinition
    public let isCompleted: Bool
    public let completionTime: TimeInterval?

    public init(
        dateKey: String,
        endsAt: Date,
        puzzle: PuzzleDefinition,
        isCompleted: Bool,
        completionTime: TimeInterval?,
    ) {
        self.dateKey = dateKey
        self.endsAt = endsAt
        self.puzzle = puzzle
        self.isCompleted = isCompleted
        self.completionTime = completionTime
    }
}
