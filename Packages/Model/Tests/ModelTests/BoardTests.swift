import Foundation
import Testing
@testable import Model

private func makePuzzle(givens: [Int?], solution: [Int]) -> PuzzleDefinition {
    PuzzleDefinition(
        id: UUID(),
        variant: .classic,
        requestedDifficulty: .easy,
        gradedDifficulty: .easy,
        seed: 42,
        givens: givens,
        solution: solution,
    )
}

@Suite
struct BoardTests {
    @Test func initFromPuzzleLocksGivens() {
        let puzzle = makePuzzle(givens: [1, nil, 3, nil], solution: [1, 2, 3, 4])
        let board = Board(puzzle: puzzle)

        #expect(board.count == 4)
        #expect(board[0].isGiven)
        #expect(board[0].value == 1)
        #expect(!board[1].isGiven)
        #expect(board[1].value == nil)
        #expect(board.filledCount == 2)
        #expect(!board.isFilled)
    }

    @Test func subscriptMutatesNonGivenCells() {
        let puzzle = makePuzzle(givens: [nil, nil], solution: [1, 2])
        var board = Board(puzzle: puzzle)

        board[0].value = 1
        board[1].notes.insert(2)

        #expect(board[0].value == 1)
        #expect(board[1].notes.contains(2))
        #expect(board.values == [1, nil])
    }

    @Test func isFilledWhenAllCellsHaveValues() {
        let puzzle = makePuzzle(givens: [1, nil], solution: [1, 2])
        var board = Board(puzzle: puzzle)
        board[1].value = 2
        #expect(board.isFilled)
        #expect(board.filledCount == 2)
    }

    @Test func codableRoundtrip() throws {
        let puzzle = makePuzzle(givens: [1, nil, nil, 4], solution: [1, 2, 3, 4])
        var board = Board(puzzle: puzzle)
        board[1].value = 2
        board[2].notes.insert(3)

        let data = try JSONEncoder().encode(board)
        let decoded = try JSONDecoder().decode(Board.self, from: data)
        #expect(decoded == board)
    }

    @Test func topologyIndexLookup() {
        let cells = [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 0, col: 1),
            GridPosition(row: 1, col: 1),
        ]
        let topology = GridTopology(
            variant: .classic,
            size: 2,
            rowCount: 2,
            colCount: 2,
            cells: cells,
            houses: [[0, 1], [1, 2]],
            houseKinds: [.row, .column],
            boxIndex: [0, 0, 0],
        )

        #expect(topology.index(row: 0, col: 0) == 0)
        #expect(topology.index(row: 1, col: 1) == 2)
        #expect(topology.index(row: 1, col: 0) == nil)
        #expect(topology.index(row: 5, col: 0) == nil)
        #expect(topology.position(of: 2) == GridPosition(row: 1, col: 1))
    }
}
