import Testing
@testable import Domain
import Model

/// The bent-line lock: locked candidates carried across a fold on the cube
/// and tredoku faces.
@Suite
struct FoldTechniqueTests {
    private func grid(_ variant: SudokuVariant, _ entries: [(cell: Int, digit: Int)]) -> SolverGrid {
        let topology = TopologyFactory.topology(for: variant)
        var givens = [Int?](repeating: nil, count: topology.cellCount)
        for entry in entries {
            givens[entry.cell] = entry.digit
        }
        return SolverGrid(context: SolverContext(topology: topology), givens: givens)
    }

    @Test func locksDigitOutOfTheContinuationOnTheCube() {
        // Rows 1-2 of the front face hold 2...7, so digit 1 in that face is
        // confined to row 0, a line that continues onto the left face's
        // row 0 (the first fold met) and the right face's row 0.
        let front = CubeNet.Face.front
        let grid = grid(.cube, [
            (cell: CubeNet.index(face: front, row: 1, col: 0), digit: 2),
            (cell: CubeNet.index(face: front, row: 1, col: 1), digit: 3),
            (cell: CubeNet.index(face: front, row: 1, col: 2), digit: 4),
            (cell: CubeNet.index(face: front, row: 2, col: 0), digit: 5),
            (cell: CubeNet.index(face: front, row: 2, col: 1), digit: 6),
            (cell: CubeNet.index(face: front, row: 2, col: 2), digit: 7),
        ])
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .bentLine)
        #expect(step?.focusDigits == [1])
        #expect(step?.placements.isEmpty == true)
        #expect(Set(step?.focusCells ?? []) == Set((0 ..< 3).map {
            CubeNet.index(face: front, row: 0, col: $0)
        }))
        let expected = (0 ..< 3).map { CubeNet.index(face: .left, row: 0, col: $0) }
        #expect(step?.eliminations.map(\.cell) == expected)
        #expect(step?.eliminations.allSatisfy { $0.digit == 1 } == true)
    }

    @Test func locksDigitOutOfTheContinuationOnTredoku() {
        // Face A (top-left) rows 1-2 hold 2...7, so digit 1 in A is confined
        // to row 0, which bends onto face B's row 0 (cells 3, 4, 5).
        let grid = grid(.tredoku, [
            (cell: 6, digit: 2), (cell: 7, digit: 3), (cell: 8, digit: 4),
            (cell: 12, digit: 5), (cell: 13, digit: 6), (cell: 14, digit: 7),
        ])
        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == .bentLine)
        #expect(step?.focusDigits == [1])
        #expect(Set(step?.focusCells ?? []) == [0, 1, 2])
        #expect(step?.eliminations.map(\.cell) == [3, 4, 5])
        #expect(step?.eliminations.allSatisfy { $0.digit == 1 } == true)
    }

    @Test func otherCliqueVariantsKeepCliquesPairwiseOnly() {
        for variant in [SudokuVariant.argyle, .antiKnight, .antiKing, .miracle, .classic] {
            let context = SolverContext(topology: TopologyFactory.topology(for: variant))
            #expect(context.foldFaces.isEmpty, "\(variant)")
        }
    }

    @Test func cubeAndTredokuMeetEveryBentLineFromBothFaces() {
        func lineCount(_ variant: SudokuVariant) -> Int {
            SolverContext(topology: TopologyFactory.topology(for: variant))
                .foldFaces.reduce(0) { $0 + $1.lines.count }
        }
        #expect(lineCount(.cube) == 72)
        #expect(lineCount(.tredoku) == 12)
    }

    /// Hard is genuinely reachable on the fold variants now: these seeds
    /// were vetted in a 30-seed sweep (cube 30/30 hard, tredoku 5/30) and
    /// need the bent-line lock; nothing else in the hard band fires on
    /// faces-only topologies.
    @Test(arguments: [
        (SudokuVariant.cube, UInt64(1)), (.cube, 2), (.cube, 3),
        (.tredoku, 3), (.tredoku, 5), (.tredoku, 11),
    ])
    func hardRequiresTheBentLineLock(variant: SudokuVariant, seed: UInt64) {
        let puzzle = PuzzleGenerator().generateNow(variant: variant, difficulty: .hard, seed: seed)
        #expect(puzzle.gradedDifficulty == .hard)

        let topology = TopologyFactory.topology(for: puzzle)
        var grid = SolverGrid(context: SolverContext(topology: topology), givens: puzzle.givens)
        var techniques = Set<Technique>()
        while !grid.isSolved, let step = TechniqueLadder.nextStep(in: grid) {
            techniques.insert(step.technique)
            guard step.apply(to: &grid) else { break }
        }
        #expect(grid.isSolved)
        #expect(techniques.contains(.bentLine))
    }

    @Test func bentLineSitsInTheHardBandWithLockedCandidates() {
        let grader = Grader()
        #expect(grader.difficulty(forHardestRank: Technique.bentLine.rank) == .hard)
        #expect(Technique.bentLine.rank == Technique.pointingPair.rank)
        #expect(Grader.maxRank(for: .medium) < Technique.bentLine.rank)
        #expect(Grader.maxRank(for: .hard) >= Technique.bentLine.rank)
    }
}
