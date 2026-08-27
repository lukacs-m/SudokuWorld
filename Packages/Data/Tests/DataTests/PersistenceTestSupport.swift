import Foundation
import Model
@testable import Data

/// Minimal fixtures for persistence roundtrips.
enum PersistenceFixtures {
    static func puzzle(variant: SudokuVariant = .classic) -> PuzzleDefinition {
        PuzzleDefinition(
            id: UUID(),
            variant: variant,
            requestedDifficulty: .medium,
            gradedDifficulty: .medium,
            seed: 42,
            givens: [1, nil, nil, 4],
            solution: [1, 2, 3, 4],
            cages: [Cage(cells: [0, 1], sum: 3)],
            parities: [2: .odd],
        )
    }

    static func savedGame(
        context: GameContext = .regular,
        elapsed: TimeInterval = 90,
    ) -> SavedGame {
        let puzzle = puzzle()
        var board = Board(puzzle: puzzle)
        board[1].value = 2
        board[2].notes.insert(3)
        let move = Move(
            index: 1,
            before: BoardCell(),
            after: BoardCell(value: 2),
            clearedPeerNotes: [2: CellNotes([3])],
        )
        return SavedGame(
            context: context,
            mode: .normal,
            puzzle: puzzle,
            board: board,
            undoStack: [move],
            redoStack: [],
            elapsed: elapsed,
            mistakes: 1,
            hintsUsed: 2,
            usedReveal: false,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_090),
        )
    }

    static func record(
        outcome: GameOutcome = .won,
        finishedAt: Date = Date(timeIntervalSince1970: 1_700_000_500),
    ) -> GameRecord {
        GameRecord(
            id: UUID(),
            variant: .killer,
            difficulty: .hard,
            mode: .hardcore,
            outcome: outcome,
            context: .daily(dateKey: "2026-07-04", variant: .classic),
            duration: 345.6,
            mistakes: 2,
            hintsUsed: 0,
            usedReveal: false,
            points: 750,
            startedAt: finishedAt.addingTimeInterval(-345.6),
            finishedAt: finishedAt,
        )
    }
}
