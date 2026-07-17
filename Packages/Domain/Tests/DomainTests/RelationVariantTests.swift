import Testing
@testable import Domain
import Model

/// Relation-clue machinery: negative-convention expansion, candidate
/// propagation, conflicts, mark derivation, and miracle's global rules.
@Suite
struct RelationVariantTests {
    // MARK: - Expansion

    @Test func kropkiExpansionCoversEveryUnmarkedPair() {
        let topology = TopologyFactory.topology(for: .kropki)
        // One white dot; the other 143 orthogonal pairs get two negatives.
        let marks = [RelationClue(a: 0, b: 1, kind: .whiteDot)]
        let edges = RelationExpansion.edges(
            variant: .kropki,
            relations: marks,
            topology: topology,
        )
        let positives = edges.count { $0.constraint == .consecutive }
        let negatives = edges.count {
            $0.constraint == .notConsecutive || $0.constraint == .notRatio
        }
        #expect(positives == 1)
        #expect(negatives == 143 * 2)
    }

    @Test func fillContextsSkipTheNegativeConvention() {
        let topology = TopologyFactory.topology(for: .kropki)
        let context = SolverContext(topology: topology, expandsNegativeConvention: false)
        #expect(context.relationEdges.isEmpty)
    }

    @Test func miracleExpandsGlobalRulesWithoutMarks() {
        let topology = TopologyFactory.topology(for: .miracle)
        let context = SolverContext(topology: topology)
        #expect(context.relationEdges.count == 144) // every orthogonal pair
        #expect(context.relationEdges.allSatisfy { $0.constraint == .notConsecutive })
        // Knight + king cliques ride on the topology.
        #expect(!topology.cliques.isEmpty)
    }

    // MARK: - Propagation fixtures

    @Test func whiteDotPrunesToNeighborsOfPlacedDigit() {
        let topology = TopologyFactory.topology(for: .classic)
        let context = SolverContext(
            topology: topology,
            relations: [RelationClue(a: 0, b: 1, kind: .whiteDot)],
            expandsNegativeConvention: false,
        )
        var givens = [Int?](repeating: nil, count: 81)
        givens[0] = 4
        let grid = SolverGrid(context: context, givens: givens)
        #expect(context.digits(in: grid.candidates[1]) == [3, 5])
    }

    @Test func greaterThanBoundsThePartner() {
        let topology = TopologyFactory.topology(for: .classic)
        let context = SolverContext(
            topology: topology,
            relations: [RelationClue(a: 0, b: 1, kind: .greaterThan)],
            expandsNegativeConvention: false,
        )
        var givens = [Int?](repeating: nil, count: 81)
        givens[0] = 3
        let grid = SolverGrid(context: context, givens: givens)
        #expect(context.digits(in: grid.candidates[1]) == [1, 2])
    }

    @Test func blackDotKeepsOnlyRatioPartners() {
        let topology = TopologyFactory.topology(for: .classic)
        let context = SolverContext(
            topology: topology,
            relations: [RelationClue(a: 9, b: 10, kind: .blackDot)],
            expandsNegativeConvention: false,
        )
        var givens = [Int?](repeating: nil, count: 81)
        givens[9] = 4
        let grid = SolverGrid(context: context, givens: givens)
        #expect(context.digits(in: grid.candidates[10]) == [2, 8])
    }

    // MARK: - Generated puzzles

    @Test func kropkiMarksMatchTheSolutionExactly() {
        let puzzle = PuzzleGenerator().generateNow(variant: .kropki, difficulty: .easy, seed: 3)
        let topology = TopologyFactory.topology(for: .kropki)
        var marked = Set<[Int]>()
        for clue in puzzle.relations {
            marked.insert([min(clue.a, clue.b), max(clue.a, clue.b)])
            let low = min(puzzle.solution[clue.a], puzzle.solution[clue.b])
            let high = max(puzzle.solution[clue.a], puzzle.solution[clue.b])
            switch clue.kind {
            case .whiteDot: #expect(high - low == 1)
            case .blackDot: #expect(high == 2 * low)
            default: Issue.record("unexpected kropki mark \(clue.kind)")
            }
        }
        // Every qualifying pair is marked (the negative convention's premise).
        for (a, b) in RelationExpansion.orthogonalPairs(in: topology)
            where !marked.contains([min(a, b), max(a, b)]) {
            let low = min(puzzle.solution[a], puzzle.solution[b])
            let high = max(puzzle.solution[a], puzzle.solution[b])
            #expect(high - low != 1)
            #expect(high != 2 * low)
        }
    }

    @Test func miracleSolutionsHonorAllThreeRules() {
        let puzzle = PuzzleGenerator().generateNow(variant: .miracle, difficulty: .easy, seed: 21)
        let solution = puzzle.solution
        for row in 0 ..< 9 {
            for col in 0 ..< 9 {
                let value = solution[row * 9 + col]
                // Orthogonal non-consecutive.
                if col < 8 {
                    #expect(abs(value - solution[row * 9 + col + 1]) != 1)
                }
                if row < 8 {
                    #expect(abs(value - solution[(row + 1) * 9 + col]) != 1)
                }
                // Anti-knight + anti-king.
                for (dr, dc) in [(1, 2), (1, -2), (2, 1), (2, -1), (1, 1), (1, -1)] {
                    let r = row + dr
                    let c = col + dc
                    guard r >= 0, r < 9, c >= 0, c < 9 else { continue }
                    #expect(value != solution[r * 9 + c])
                }
            }
        }
    }

    @Test func conflictDetectorFlagsRelationViolations() {
        let puzzle = PuzzleGenerator().generateNow(variant: .kropki, difficulty: .easy, seed: 5)
        let detector = ConflictDetector(puzzle: puzzle)
        // Violate the first mark whose endpoints aren't both given.
        guard let clue = puzzle.relations.first(where: {
            puzzle.givens[$0.a] == nil || puzzle.givens[$0.b] == nil
        }) else {
            Issue.record("no violable mark found")
            return
        }
        var board = Board(puzzle: puzzle)
        let solutionA = puzzle.solution[clue.a]
        board[clue.a] = BoardCell(value: solutionA, isGiven: false)
        // A partner value that breaks both dot kinds: same digit is illegal
        // via the row anyway, so pick something non-consecutive, non-ratio.
        let bad = [1, 9, 5, 7].first {
            $0 != solutionA && abs($0 - solutionA) != 1
                && $0 != 2 * solutionA && solutionA != 2 * $0
        }!
        board[clue.b] = BoardCell(value: bad, isGiven: false)
        let conflicts = detector.conflicts(in: board)
        #expect(conflicts.contains(clue.a))
        #expect(conflicts.contains(clue.b))
    }

    @Test func relationPuzzlesCarveWellBelowClassicDensity() {
        let puzzle = PuzzleGenerator().generateNow(variant: .kropki, difficulty: .expert, seed: 8)
        let givenCount = puzzle.givens.count { $0 != nil }
        #expect(givenCount < 20, "expert kropki should lean on its marks, got \(givenCount) givens")
    }
}
