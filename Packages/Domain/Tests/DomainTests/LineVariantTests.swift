import Testing
@testable import Domain
import Model

/// Thermometer and arrow machinery: placement validity, solver expansion,
/// interval propagation, and conflicts.
@Suite
struct LineVariantTests {
    @Test func thermometersExpandIntoGreaterChains() {
        let topology = TopologyFactory.topology(for: .thermo)
        let context = SolverContext(topology: topology, thermometers: [[0, 1, 2, 3]])
        let greater = context.relationEdges.filter { $0.constraint == .greater }
        #expect(greater.count == 3)
        #expect(greater.allSatisfy { $0.a == $0.b + 1 })
    }

    @Test func placedThermometersStrictlyIncrease() {
        let puzzle = PuzzleGenerator().generateNow(variant: .thermo, difficulty: .easy, seed: 12)
        #expect(!puzzle.thermometers.isEmpty)
        var seen = Set<Int>()
        for path in puzzle.thermometers {
            #expect(path.count >= 3)
            for step in 1 ..< path.count {
                #expect(puzzle.solution[path[step]] > puzzle.solution[path[step - 1]])
            }
            #expect(seen.isDisjoint(with: path), "thermometers share cells")
            seen.formUnion(path)
        }
    }

    @Test func placedArrowsSumToTheirCircles() {
        let puzzle = PuzzleGenerator().generateNow(variant: .arrow, difficulty: .easy, seed: 13)
        #expect(!puzzle.arrows.isEmpty)
        var seen = Set<Int>()
        for arrow in puzzle.arrows {
            #expect(arrow.shaft.count >= 2)
            let sum = arrow.shaft.map { puzzle.solution[$0] }.reduce(0, +)
            #expect(sum == puzzle.solution[arrow.circle])
            let cells = [arrow.circle] + arrow.shaft
            #expect(seen.isDisjoint(with: cells), "arrows share cells")
            seen.formUnion(cells)
        }
    }

    @Test func sumLinePropagationBoundsTheCircle() {
        let topology = TopologyFactory.topology(for: .arrow)
        // Shaft of two cells in different rows/boxes from the circle.
        let arrow = Arrow(circle: 0, shaft: [30, 60])
        let context = SolverContext(topology: topology, arrows: [arrow])
        var grid = SolverGrid(context: context, givens: [Int?](repeating: nil, count: 81))
        let propagated = grid.propagate()
        #expect(propagated)
        // Two open cells sum to at least 1+1=2: the circle can't be 1.
        #expect(!context.digits(in: grid.candidates[0]).contains(1))
    }

    @Test func conflictDetectorFlagsWrongArrowSums() {
        let puzzle = PuzzleGenerator().generateNow(variant: .arrow, difficulty: .easy, seed: 14)
        guard let arrow = puzzle.arrows.first else {
            Issue.record("no arrow placed")
            return
        }
        var board = Board(puzzle: puzzle)
        // Fill the arrow correctly except overshoot one shaft cell.
        board[arrow.circle] = BoardCell(
            value: puzzle.solution[arrow.circle],
            isGiven: puzzle.givens[arrow.circle] != nil,
        )
        for cell in arrow.shaft {
            board[cell] = BoardCell(
                value: puzzle.solution[cell],
                isGiven: puzzle.givens[cell] != nil,
            )
        }
        let wrongCell = arrow.shaft[0]
        let wrongValue = puzzle.solution[wrongCell] == 9 ? 8 : puzzle.solution[wrongCell] + 1
        board[wrongCell] = BoardCell(value: wrongValue, isGiven: false)
        let conflicts = ConflictDetector(puzzle: puzzle).conflicts(in: board)
        #expect(conflicts.contains(arrow.circle) || conflicts.contains(wrongCell))
    }
}
