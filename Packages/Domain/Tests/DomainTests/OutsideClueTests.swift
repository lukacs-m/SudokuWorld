import Testing
@testable import Domain
import Model

/// Outside-clue machinery: line resolution, clue derivation, propagation,
/// uniqueness participation, and conflicts.
@Suite
struct OutsideClueTests {
    private let topology = TopologyFactory.topology(for: .sandwich)

    @Test func linesReadFromTheirEdge() {
        let leading = OutsideClues.line(
            for: OutsideClue(kind: .sandwichSum, side: .leading, offset: 2, value: 0),
            topology: topology,
        )
        #expect(leading == (18 ... 26).map(\.self))

        let bottomColumn = OutsideClues.line(
            for: OutsideClue(kind: .skyscraperCount, side: .bottom, offset: 4, value: 0),
            topology: topology,
        )
        #expect(bottomColumn.first == 76) // r8c4
        #expect(bottomColumn.last == 4) // r0c4

        let diagonal = OutsideClues.line(
            for: OutsideClue(kind: .diagonalSum, side: .top, offset: 6, value: 0),
            topology: topology,
        )
        #expect(diagonal == [6, 16, 26]) // (0,6) ↘ (1,7) ↘ (2,8)
    }

    @Test func derivedCluesMatchTheSolution() {
        let puzzle = PuzzleGenerator().generateNow(variant: .sandwich, difficulty: .easy, seed: 4)
        #expect(puzzle.outsideClues.count == 18)
        for clue in puzzle.outsideClues {
            let cells = OutsideClues.line(for: clue, topology: topology)
            let values = cells.map { puzzle.solution[$0] }
            #expect(OutsideClues.satisfied(clue: clue, lineValues: values, size: 9))
        }
    }

    @Test func skyscraperSpecialsForceTheLine() {
        let clueOne = OutsideClue(kind: .skyscraperCount, side: .leading, offset: 0, value: 1)
        let context = SolverContext(
            topology: TopologyFactory.topology(for: .skyscraper),
            outsideClues: [clueOne],
        )
        var grid = SolverGrid(context: context, givens: [Int?](repeating: nil, count: 81))
        let propagated = grid.propagate()
        #expect(propagated)
        #expect(grid.values[0] == 9) // clue 1 pins the 9 to the edge

        let clueAll = OutsideClue(kind: .skyscraperCount, side: .leading, offset: 1, value: 9)
        let ascending = SolverContext(
            topology: TopologyFactory.topology(for: .skyscraper),
            outsideClues: [clueAll],
        )
        var ascendingGrid = SolverGrid(
            context: ascending,
            givens: [Int?](repeating: nil, count: 81),
        )
        let ok = ascendingGrid.propagate()
        #expect(ok)
        #expect((9 ... 17).map { ascendingGrid.values[$0] } == Array(1 ... 9))
    }

    @Test func littleKillerRidesTheSumLineEngine() {
        let clue = OutsideClue(kind: .diagonalSum, side: .top, offset: 7, value: 4)
        let context = SolverContext(
            topology: TopologyFactory.topology(for: .littleKiller),
            outsideClues: [clue],
        )
        #expect(context.sumLines.count == 1)
        var grid = SolverGrid(context: context, givens: [Int?](repeating: nil, count: 81))
        let ok = grid.propagate()
        #expect(ok)
        // Two cells summing to 4: each is at most 3.
        let cells = OutsideClues.line(for: clue, topology: context.topology)
        for cell in cells {
            #expect(context.digits(in: grid.candidates[cell]).allSatisfy { $0 <= 3 })
        }
    }

    @Test func conflictDetectorFlagsBrokenClueLines() {
        let puzzle = PuzzleGenerator().generateNow(
            variant: .skyscraper,
            difficulty: .easy,
            seed: 9,
        )
        guard let clue = puzzle.outsideClues.first else {
            Issue.record("no clue derived")
            return
        }
        let cells = OutsideClues.line(for: clue, topology: topology)
        var board = Board(puzzle: puzzle)
        // Fill the whole line from the solution, then swap two non-given
        // values to break the visibility count without a house conflict…
        for cell in cells {
            board[cell] = BoardCell(
                value: puzzle.solution[cell],
                isGiven: puzzle.givens[cell] != nil,
            )
        }
        // …by reversing the line's values across non-given cells.
        let open = cells.filter { puzzle.givens[$0] == nil }
        guard open.count >= 2 else { return }
        let values = open.map { puzzle.solution[$0] }
        for (cell, value) in zip(open, values.reversed()) where values != values.reversed() {
            board[cell] = BoardCell(value: value, isGiven: false)
        }
        let conflicts = ConflictDetector(puzzle: puzzle).conflicts(in: board)
        // Either the reversal broke the clue (flagged) or it happened to be
        // a palindrome (nothing to assert).
        if values != values.reversed() {
            let lineValues = cells.compactMap { board[$0].value }
            if !OutsideClues.satisfied(clue: clue, lineValues: lineValues, size: 9) {
                #expect(!conflicts.isDisjoint(with: cells))
            }
        }
    }
}
