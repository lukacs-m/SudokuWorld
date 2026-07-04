public import Foundation

/// A resumable in-flight game: everything needed to restore play exactly,
/// including undo history and the frozen elapsed time.
public struct SavedGame: Equatable, Sendable, Codable {
    public let context: GameContext
    public let mode: GameMode
    public let puzzle: PuzzleDefinition
    public let board: Board
    public let undoStack: [Move]
    public let redoStack: [Move]
    /// Play time accumulated so far; never counts backgrounded time.
    public let elapsed: TimeInterval
    public let mistakes: Int
    public let hintsUsed: Int
    public let usedReveal: Bool
    public let startedAt: Date
    public let updatedAt: Date

    public init(
        context: GameContext,
        mode: GameMode,
        puzzle: PuzzleDefinition,
        board: Board,
        undoStack: [Move],
        redoStack: [Move],
        elapsed: TimeInterval,
        mistakes: Int,
        hintsUsed: Int,
        usedReveal: Bool,
        startedAt: Date,
        updatedAt: Date,
    ) {
        self.context = context
        self.mode = mode
        self.puzzle = puzzle
        self.board = board
        self.undoStack = undoStack
        self.redoStack = redoStack
        self.elapsed = elapsed
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.usedReveal = usedReveal
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}
