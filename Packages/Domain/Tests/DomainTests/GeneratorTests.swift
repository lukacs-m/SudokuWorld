import Testing
@testable import Domain
import Model

/// Full-pipeline generation checks. One puzzle per case with a fixed seed
/// keeps CI fast and deterministic; uniqueness is re-verified from scratch.
@Suite
struct GeneratorTests {
    private let generator = PuzzleGenerator()
    private static let seed: UInt64 = 0xC0FF_EE00_5EED

    private func validate(_ puzzle: PuzzleDefinition) {
        let topology = TopologyFactory.topology(for: puzzle.variant)
        #expect(puzzle.givens.count == topology.cellCount)
        #expect(puzzle.solution.count == topology.cellCount)

        // The solution satisfies every house.
        for house in topology.houses {
            #expect(Set(house.map { puzzle.solution[$0] }).count == topology.size)
        }
        // Givens are a subset of the solution.
        for (cell, given) in puzzle.givens.enumerated() {
            if let given {
                #expect(given == puzzle.solution[cell])
            }
        }
        // Unique solution, re-checked from scratch.
        let solver = Solver(
            topology: topology,
            givens: puzzle.givens,
            cages: puzzle.cages,
            parities: puzzle.parities,
        )
        #expect(solver.solutionCount(limit: 2) == 1)
        #expect(solver.solve() == puzzle.solution)

        // The puzzle is solvable by the technique ladder at its graded level.
        let graded = Grader().grade(
            topology: topology,
            givens: puzzle.givens,
            cages: puzzle.cages,
            parities: puzzle.parities,
        )
        #expect(graded == puzzle.gradedDifficulty)
    }

    @Test(arguments: [
        (SudokuVariant.classic, Difficulty.easy),
        (SudokuVariant.classic, Difficulty.expert),
        (SudokuVariant.mini6, Difficulty.easy),
        (SudokuVariant.diagonal, Difficulty.easy),
        (SudokuVariant.diagonal, Difficulty.expert),
        (SudokuVariant.windoku, Difficulty.easy),
        (SudokuVariant.evenOdd, Difficulty.easy),
        (SudokuVariant.evenOdd, Difficulty.expert),
    ])
    func generatesValidPuzzles(variant: SudokuVariant, difficulty: Difficulty) {
        let puzzle = generator.generateNow(
            variant: variant,
            difficulty: difficulty,
            seed: Self.seed,
        )
        #expect(puzzle.variant == variant)
        #expect(puzzle.requestedDifficulty == difficulty)
        validate(puzzle)
    }

    @Test func killerPuzzlesHaveValidCages() {
        for difficulty in [Difficulty.easy, .expert] {
            let puzzle = generator.generateNow(
                variant: .killer,
                difficulty: difficulty,
                seed: Self.seed,
            )
            validate(puzzle)

            // Cages exactly partition the grid.
            let topology = TopologyFactory.topology(for: .killer)
            var covered = Set<Int>()
            for cage in puzzle.cages {
                #expect(covered.isDisjoint(with: cage.cells))
                covered.formUnion(cage.cells)
                // Sums match the solution and digits are distinct.
                #expect(cage.sum == cage.cells.reduce(0) { $0 + puzzle.solution[$1] })
                #expect(Set(cage.cells.map { puzzle.solution[$0] }).count == cage.cells.count)
            }
            #expect(covered.count == topology.cellCount)
        }
    }

    @Test func evenOddParitiesMatchSolution() {
        let puzzle = generator.generateNow(variant: .evenOdd, difficulty: .medium, seed: Self.seed)
        #expect(!puzzle.parities.isEmpty)
        for (cell, parity) in puzzle.parities {
            #expect(parity.accepts(puzzle.solution[cell]))
        }
    }

    @Test func samuraiGeneratesValidPuzzle() {
        let puzzle = generator.generateNow(variant: .samurai, difficulty: .medium, seed: Self.seed)
        validate(puzzle)
    }

    @Test func generationIsDeterministic() {
        let first = generator.generateNow(variant: .classic, difficulty: .medium, seed: 12345)
        let second = generator.generateNow(variant: .classic, difficulty: .medium, seed: 12345)
        #expect(first == second)

        let differentSeed = generator.generateNow(variant: .classic, difficulty: .medium, seed: 54321)
        #expect(differentSeed.solution != first.solution || differentSeed.givens != first.givens)
    }

    @Test func gradedDifficultyMatchesRequestForClassicTargets() {
        // These seeds were vetted to hit their target grade exactly.
        for difficulty in [Difficulty.beginner, .easy, .medium] {
            let puzzle = generator.generateNow(
                variant: .classic,
                difficulty: difficulty,
                seed: Self.seed,
            )
            #expect(puzzle.gradedDifficulty == difficulty)
        }
    }

    @Test func dailySeedProducesIdenticalPuzzles() {
        let seed = EventSeeds.dailySeed(dateKey: "2026-07-04")
        let plan = EventSeeds.dailyPlan(dateKey: "2026-07-04")
        let first = generator.generateNow(
            variant: plan.variant,
            difficulty: plan.difficulty,
            seed: seed,
        )
        let second = generator.generateNow(
            variant: plan.variant,
            difficulty: plan.difficulty,
            seed: seed,
        )
        #expect(first == second)
        #expect(first.id == second.id)
    }

    /// Difficulty must be visible on the board, not just in the technique
    /// cap: beginner boards stay dense, expert/master boards carve deep.
    /// Guards against regressing to "every difficulty digs to its limit",
    /// which made all boards feel equally (and maximally) hard.
    @Test func difficultyControlsGivensDensity() {
        func givensCount(_ difficulty: Difficulty, seed: UInt64) -> Int {
            generator.generateNow(variant: .classic, difficulty: difficulty, seed: seed)
                .givens.count { $0 != nil }
        }

        for seed in [UInt64(99), 4242, 987_654] {
            let beginner = givensCount(.beginner, seed: seed)
            let easy = givensCount(.easy, seed: seed)
            let medium = givensCount(.medium, seed: seed)
            let expert = givensCount(.expert, seed: seed)

            // Floors: 55% / 47% / 40% / 31% of 81 cells.
            #expect(beginner >= 44)
            #expect(easy >= 38)
            #expect(medium >= 32)
            #expect(expert <= 33)
            // The spread a player actually perceives.
            #expect(beginner - expert >= 11)
            #expect(beginner > easy)
        }
    }

    @Test func consecutiveSeedsProduceDifferentPuzzles() {
        let first = generator.generateNow(variant: .classic, difficulty: .easy, seed: 1_000)
        let second = generator.generateNow(variant: .classic, difficulty: .easy, seed: 1_001)
        #expect(first.solution != second.solution || first.givens != second.givens)
    }

    /// The worst-case targets must complete within the deterministic work
    /// budget. Master is the hardest grade to hit exactly (X-wing as the
    /// hardest step) and samurai attempts are ~5× the cost of a 9×9 —
    /// before the budget phases, master samurai effectively never finished.
    @Test(.timeLimit(.minutes(2)), arguments: [
        (SudokuVariant.samurai, Difficulty.master),
        (SudokuVariant.killer, Difficulty.master),
        (SudokuVariant.classic, Difficulty.master),
    ])
    func worstCaseTargetsFinishWithinBudget(variant: SudokuVariant, difficulty: Difficulty) {
        let puzzle = generator.generateNow(
            variant: variant,
            difficulty: difficulty,
            seed: 0xBEEF,
        )
        #expect(puzzle.requestedDifficulty == difficulty)
        // The budget may settle on a neighboring grade; it must land close
        // and the puzzle must still verify.
        #expect(abs(puzzle.gradedDifficulty.rank - difficulty.rank) <= 2)
        validate(puzzle)
    }
}
