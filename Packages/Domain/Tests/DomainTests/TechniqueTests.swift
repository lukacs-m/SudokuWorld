import Testing
@testable import Domain
import Model

/// Builds a solver grid for the classic topology from sparse givens.
private func classicGrid(_ entries: [(row: Int, col: Int, digit: Int)]) -> SolverGrid {
    let topology = TopologyFactory.topology(for: .classic)
    var givens = [Int?](repeating: nil, count: 81)
    for entry in entries {
        givens[entry.row * 9 + entry.col] = entry.digit
    }
    return SolverGrid(context: SolverContext(topology: topology), givens: givens)
}

@Suite
struct TechniqueTests {
    @Test func nakedSingleIsFound() {
        // Row 0 holds 1-8; the last cell must be 9.
        let grid = classicGrid((0..<8).map { (row: 0, col: $0, digit: $0 + 1) })
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .nakedSingle)
        #expect(step?.placements.first?.cell == 8)
        #expect(step?.placements.first?.digit == 9)
    }

    @Test func hiddenSingleIsFound() {
        // Four 1s (all in distinct rows/columns/boxes) leave (0,0) as the
        // only home for digit 1 in row 0.
        let grid = classicGrid([
            (row: 1, col: 4, digit: 1),
            (row: 2, col: 7, digit: 1),
            (row: 4, col: 1, digit: 1),
            (row: 7, col: 2, digit: 1),
        ])
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .hiddenSingle)
        #expect(step?.placements.first?.cell == 0)
        #expect(step?.placements.first?.digit == 1)
    }

    @Test func nakedPairIsFound() {
        // Row 0 cols 2-8 hold 3...9, so (0,0) and (0,1) are both {1,2}:
        // a naked pair that strips 1 and 2 from the rest of box 0.
        let grid = classicGrid((2..<9).map { (row: 0, col: $0, digit: $0 + 1) })
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .nakedPair)
        let eliminated = step.map { Set($0.eliminations.map(\.cell)) } ?? []
        // Eliminations land in box 0 rows 1-2.
        #expect(!eliminated.isEmpty)
        #expect(eliminated.isSubset(of: [9, 10, 11, 18, 19, 20]))
        #expect(step?.eliminations.allSatisfy { $0.digit == 1 || $0.digit == 2 } == true)
    }

    @Test func pointingPairIsFound() {
        // Rows 1-2 of box 0 are fully occupied by 2...7, so digit 1 in box 0
        // is confined to row 0 → it falls out of row 0 outside the box.
        let grid = classicGrid([
            (row: 1, col: 0, digit: 2),
            (row: 1, col: 1, digit: 3),
            (row: 1, col: 2, digit: 4),
            (row: 2, col: 0, digit: 5),
            (row: 2, col: 1, digit: 6),
            (row: 2, col: 2, digit: 7),
        ])
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .pointingPair)
        #expect(step?.focusDigits == [1])
        let eliminationCells = step.map { Set($0.eliminations.map(\.cell)) } ?? []
        #expect(!eliminationCells.isEmpty)
        // All eliminations are in row 0, outside box 0.
        #expect(eliminationCells.allSatisfy { $0 < 9 && $0 >= 3 })
    }

    @Test func xWingIsFound() {
        // Rows 2 and 6 each miss {5,9} / {5,8} exactly at columns 3 and 7 —
        // digit 5 forms an X-wing eliminating 5 from the rest of those columns.
        var entries: [(row: Int, col: Int, digit: Int)] = []
        let rowTwo = [1, 2, 3, 0, 4, 6, 7, 0, 8]
        let rowSix = [2, 3, 4, 0, 6, 7, 9, 0, 1]
        for (col, digit) in rowTwo.enumerated() where digit != 0 {
            entries.append((row: 2, col: col, digit: digit))
        }
        for (col, digit) in rowSix.enumerated() where digit != 0 {
            entries.append((row: 6, col: col, digit: digit))
        }
        let grid = classicGrid(entries)
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .xWing)
        #expect(step?.focusDigits == [5])
        let corners = Set(step?.focusCells ?? [])
        #expect(corners == Set([2 * 9 + 3, 2 * 9 + 7, 6 * 9 + 3, 6 * 9 + 7]))
        #expect(step?.eliminations.allSatisfy { $0.digit == 5 } == true)
        #expect(step?.eliminations.isEmpty == false)
    }

    @Test func cagePlacementIsFound() {
        // A single-cell cage forces its sum.
        let topology = TopologyFactory.topology(for: .killer)
        let context = SolverContext(topology: topology, cages: [Cage(cells: [40], sum: 7)])
        let grid = SolverGrid(context: context, givens: [Int?](repeating: nil, count: 81))
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .cageArithmetic)
        #expect(step?.placements.first?.cell == 40)
        #expect(step?.placements.first?.digit == 7)
    }

    @Test func cageEliminationIsFound() {
        // A two-cell cage summing to 3 only admits {1,2}.
        let topology = TopologyFactory.topology(for: .killer)
        let context = SolverContext(topology: topology, cages: [Cage(cells: [0, 1], sum: 3)])
        let grid = SolverGrid(context: context, givens: [Int?](repeating: nil, count: 81))
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .cageArithmetic)
        let digits = Set(step?.eliminations.map(\.digit) ?? [])
        #expect(digits == Set(3...9))
        #expect(Set(step?.eliminations.map(\.cell) ?? []) == [0, 1])
    }
}

@Suite
struct GraderTests {
    @Test func fullGridGradesBeginner() {
        let topology = TopologyFactory.topology(for: .classic)
        let grader = Grader()
        let grade = grader.grade(topology: topology, givens: Fixtures.classicSolution)
        #expect(grade == .beginner)
    }

    @Test func knownEasyPuzzleGrades() {
        let topology = TopologyFactory.topology(for: .classic)
        let grader = Grader()
        let grade = grader.grade(topology: topology, givens: Fixtures.classicGivens)
        // The Wikipedia example solves with singles.
        #expect(grade != nil)
        #expect(grade.map { $0 <= .medium } == true)
    }

    @Test func contradictionGradesNil() {
        let topology = TopologyFactory.topology(for: .classic)
        var givens = [Int?](repeating: nil, count: 81)
        givens[0] = 5
        givens[1] = 5
        #expect(Grader().grade(topology: topology, givens: givens) == nil)
    }

    @Test func rankMappingIsMonotonic() {
        let grader = Grader()
        let grades = (0...9).map { grader.difficulty(forHardestRank: $0) }
        for pair in zip(grades, grades.dropFirst()) {
            #expect(pair.0 <= pair.1)
        }
        #expect(grader.difficulty(forHardestRank: 0) == .beginner)
        #expect(grader.difficulty(forHardestRank: 9) == .master)
    }
}
