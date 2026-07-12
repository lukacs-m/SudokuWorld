import Foundation
public import Model

/// The generation pipeline: fill a solution, apply variant extras (cages,
/// parity marks), carve givens under the difficulty's technique cap and
/// givens floor, and retry with deterministically evolved seeds on a miss.
///
/// Fully deterministic: the same (variant, difficulty, seed) always yields a
/// byte-identical puzzle, which is what makes worldwide daily challenges work.
/// Retries are bounded by a deterministic **work budget** (never wall-clock,
/// which would break cross-device determinism) in three phases: hunt the
/// exact grade first, then accept a neighboring grade, then take the best
/// candidate seen — so generation always finishes promptly, even for
/// hard-to-hit targets like Master on samurai's 369-cell grid.
public struct PuzzleGenerator: Sendable {
    public init() {}

    /// Total attempts: generous for 9×9-class grids, tight for samurai-size
    /// boards where every attempt is ~5× more expensive.
    static func attemptBudget(cellCount: Int) -> Int {
        cellCount > 200 ? 3 : 40
    }

    /// Generates on the global concurrent executor. `@concurrent` matters:
    /// under NonisolatedNonsendingByDefault a plain async method would run on
    /// the caller's actor — typically the MainActor of a view model.
    @concurrent
    public func generate(
        variant: SudokuVariant,
        difficulty: Difficulty,
        seed: UInt64,
    ) async -> PuzzleDefinition {
        generateNow(variant: variant, difficulty: difficulty, seed: seed)
    }

    /// Synchronous core — exposed for tests and for callers already off-main.
    public func generateNow(
        variant: SudokuVariant,
        difficulty: Difficulty,
        seed: UInt64,
    ) -> PuzzleDefinition {
        let topology = TopologyFactory.topology(for: variant)
        let fillContext = SolverContext(topology: topology)
        let grader = Grader()

        let maxAttempts = Self.attemptBudget(cellCount: topology.cellCount)
        // Settle phases per tier. Beginner–medium hunt their exact grade
        // through the whole budget (attempts are cheap and hits reliable,
        // thanks to hardening). Hard and expert are the thin bands — a dig
        // often jumps from "pairs suffice" straight to "needs chains" — so
        // they get a real hunt before settling on a neighbor. Master hits
        // reliably (chain-requiring boards are common at minimal depth) and
        // settles fast. Large grids settle fastest — their attempts are ~5×
        // the cost.
        let (exactPhase, nearPhase): (Int, Int) = if topology.cellCount > 200 {
            (max(1, maxAttempts / 3), max(2, (maxAttempts * 2) / 3))
        } else if difficulty == .hard || difficulty == .expert {
            (4, 8)
        } else if difficulty == .master {
            (2, 4)
        } else {
            (maxAttempts, maxAttempts)
        }

        var attemptSeed = seed
        var best: (puzzle: PuzzleDefinition, distance: Int)?

        for attemptIndex in 0 ..< maxAttempts {
            if let candidate = attempt(
                topology: topology,
                fillContext: fillContext,
                variant: variant,
                difficulty: difficulty,
                seed: seed,
                attemptSeed: attemptSeed,
                grader: grader,
            ) {
                let distance = abs(candidate.gradedDifficulty.rank - difficulty.rank)
                if distance == 0 {
                    return candidate
                }
                if best == nil || distance < (best?.distance ?? .max) {
                    best = (candidate, distance)
                }
            }
            if attemptIndex + 1 >= exactPhase,
               let settled = best, settled.distance <= 1
            {
                return settled.puzzle
            }
            // Settling on a farther grade needs the full budget — otherwise
            // keep hunting; the post-loop fallback still returns the best.
            if attemptIndex + 1 >= nearPhase,
               let settled = best, settled.distance <= 2
            {
                return settled.puzzle
            }
            attemptSeed = SplitMix64.evolve(attemptSeed)
        }
        if let best {
            return best.puzzle
        }
        return lastResortPuzzle(
            topology: topology,
            fillContext: fillContext,
            variant: variant,
            difficulty: difficulty,
            seed: seed,
        )
    }

    /// The fewest clues a puzzle of this difficulty may keep, as a fraction of
    /// the grid. This is what makes difficulties *feel* different to humans:
    /// beginner boards stay dense (≈45 givens on a 9×9) even though deeper
    /// digs would still be "solvable with singles", while master carves to
    /// the technique-ladder minimum.
    static func minimumGivens(for difficulty: Difficulty, cellCount: Int) -> Int {
        let fraction = switch difficulty {
        case .beginner: 0.55
        case .easy: 0.47
        case .medium: 0.40
        case .hard: 0.35
        case .expert: 0.31
        case .master: 0.0
        }
        return Int(Double(cellCount) * fraction)
    }

    /// How far hardening (stage 2 of the carve) may dig below the floor when
    /// the floor state grades under the target. Each tier keeps a distinct
    /// density so "hard" never carves down to master sparseness.
    static func hardeningFloor(for difficulty: Difficulty, cellCount: Int) -> Int {
        let fraction = switch difficulty {
        case .beginner, .easy: 0.47
        case .medium: 0.35
        case .hard: 0.32
        case .expert: 0.29
        case .master: 0.0
        }
        return Int(Double(cellCount) * fraction)
    }

    // MARK: - Single attempt

    private func attempt(
        topology: GridTopology,
        fillContext: SolverContext,
        variant: SudokuVariant,
        difficulty: Difficulty,
        seed: UInt64,
        attemptSeed: UInt64,
        grader: Grader,
    ) -> PuzzleDefinition? {
        var rng = Xoshiro256StarStar(seed: attemptSeed)

        // Jigsaw regions are per-puzzle structure: each attempt draws a new
        // partition, so a hard-to-fill layout just costs one retry.
        var topology = topology
        var fillContext = fillContext
        var irregularBoxes: [Int]?
        if variant == .jigsaw {
            let boxes = RegionPartitioner.partition(size: topology.size, rng: &rng)
            irregularBoxes = boxes
            topology = JigsawTopology.build(boxes: boxes)
            fillContext = SolverContext(topology: topology)
        }

        guard let solution = GridFiller.fill(context: fillContext, rng: &rng) else {
            return nil
        }

        let outcome: DifficultyTargeter.Outcome?
        var cages: [Cage] = []
        var parities: [Int: CellParity] = [:]

        switch variant {
        case .killer:
            cages = CagePartitioner.partition(
                topology: topology,
                solution: solution,
                difficulty: difficulty,
                rng: &rng,
            )
            outcome = killerGivens(
                topology: topology,
                cages: cages,
                solution: solution,
                target: difficulty,
                grader: grader,
                rng: &rng,
            )

        case .evenOdd:
            parities = parityMarks(
                topology: topology,
                solution: solution,
                difficulty: difficulty,
                rng: &rng,
            )
            let context = SolverContext(topology: topology, parities: parities)
            outcome = carveAndTune(
                context: context,
                solution: solution,
                difficulty: difficulty,
                grader: grader,
                rng: &rng,
            )

        default:
            outcome = carveAndTune(
                context: fillContext,
                solution: solution,
                difficulty: difficulty,
                grader: grader,
                rng: &rng,
            )
        }

        guard let outcome else { return nil }
        return PuzzleDefinition(
            id: Self.deterministicID(seed: seed, variant: variant, difficulty: difficulty),
            variant: variant,
            requestedDifficulty: difficulty,
            gradedDifficulty: outcome.graded,
            seed: seed,
            givens: outcome.givens,
            solution: solution,
            cages: cages,
            parities: parities,
            irregularBoxes: irregularBoxes,
        )
    }

    private func carveAndTune(
        context: SolverContext,
        solution: [Int],
        difficulty: Difficulty,
        grader: Grader,
        rng: inout Xoshiro256StarStar,
    ) -> DifficultyTargeter.Outcome? {
        // Symmetry is an aesthetic for approachable boards; expert/master
        // digs need the freedom of single-cell removals to reach the deep,
        // technique-heavy configurations their grades require.
        let carved = GivensCarver.carve(
            context: context,
            solution: solution,
            target: difficulty,
            minimumGivens: Self.minimumGivens(
                for: difficulty,
                cellCount: context.cellCount,
            ),
            hardeningFloor: Self.hardeningFloor(
                for: difficulty,
                cellCount: context.cellCount,
            ),
            symmetric: difficulty <= .hard,
            rng: &rng,
            grader: grader,
        )
        guard let graded = carved.graded else { return nil }
        return DifficultyTargeter.Outcome(givens: carved.givens, graded: graded)
    }

    /// Killer puzzles start with no givens at all; clues are added one at a
    /// time until the technique ladder can finish the puzzle (which also
    /// guarantees uniqueness), difficulty-tuned, then topped up to the
    /// difficulty's givens floor so easier killers stay approachable.
    private func killerGivens(
        topology: GridTopology,
        cages: [Cage],
        solution: [Int],
        target: Difficulty,
        grader: Grader,
        rng: inout Xoshiro256StarStar,
    ) -> DifficultyTargeter.Outcome? {
        let context = SolverContext(topology: topology, cages: cages)
        var givens = [Int?](repeating: nil, count: topology.cellCount)
        var addQueue = Array(0 ..< topology.cellCount).shuffled(using: &rng)

        // Capped at the target: stops at the same clue set as "solvable, then
        // eased to the target grade" would, but every failing check on the
        // way stalls early instead of searching the full technique catalog.
        while !grader.solvesWithin(target: target, context: context, givens: givens) {
            guard let cell = addQueue.popLast() else { return nil }
            givens[cell] = solution[cell]
        }

        // Remaining queue entries double as the easing pool for tuning.
        let easingUnits = addQueue.reversed().map { [$0] }
        guard let tuned = DifficultyTargeter.tune(
            context: context,
            givens: givens,
            removedUnits: easingUnits,
            solution: solution,
            target: target,
            grader: grader,
        ) else { return nil }

        // Top up to the floor: extra givens only ever make the puzzle easier,
        // so re-grade once at the end.
        var topped = tuned.givens
        var count = topped.count { $0 != nil }
        let floor = Self.minimumGivens(for: target, cellCount: topology.cellCount)
        if count < floor {
            for cell in Array(0 ..< topology.cellCount).shuffled(using: &rng)
                where topped[cell] == nil
            {
                topped[cell] = solution[cell]
                count += 1
                if count >= floor {
                    break
                }
            }
            let regraded = grader.grade(context: context, givens: topped) ?? tuned.graded
            return DifficultyTargeter.Outcome(givens: topped, graded: regraded)
        }
        return tuned
    }

    private func parityMarks(
        topology: GridTopology,
        solution: [Int],
        difficulty: Difficulty,
        rng: inout Xoshiro256StarStar,
    ) -> [Int: CellParity] {
        let fraction = switch difficulty {
        case .beginner: 0.45
        case .easy: 0.40
        case .medium: 0.35
        case .hard: 0.30
        case .expert: 0.25
        case .master: 0.20
        }
        let markCount = Int(Double(topology.cellCount) * fraction)
        let marked = Array(0 ..< topology.cellCount).shuffled(using: &rng).prefix(markCount)

        var parities: [Int: CellParity] = [:]
        for cell in marked {
            parities[cell] = solution[cell].isMultiple(of: 2) ? .even : .odd
        }
        return parities
    }

    /// Unreachable in practice (an attempt always yields some tunable puzzle);
    /// keeps the API total without force-unwraps.
    private func lastResortPuzzle(
        topology: GridTopology,
        fillContext: SolverContext,
        variant: SudokuVariant,
        difficulty: Difficulty,
        seed: UInt64,
    ) -> PuzzleDefinition {
        var rng = Xoshiro256StarStar(seed: seed)
        let solution = GridFiller.fill(context: fillContext, rng: &rng)
            ?? Array(repeating: 1, count: topology.cellCount)
        var givens: [Int?] = solution
        // Leave a token challenge: blank one cell per house where possible.
        for house in topology.houses {
            if let cell = house.first(where: { givens[$0] != nil }) {
                givens[cell] = nil
            }
        }
        let graded = Grader().grade(topology: topology, givens: givens) ?? .beginner
        return PuzzleDefinition(
            id: Self.deterministicID(seed: seed, variant: variant, difficulty: difficulty),
            variant: variant,
            requestedDifficulty: difficulty,
            gradedDifficulty: graded,
            seed: seed,
            givens: givens,
            solution: solution,
        )
    }

    /// A UUID derived from the generation inputs, so regenerating the same
    /// puzzle (e.g. a daily challenge) yields a stable identity.
    static func deterministicID(
        seed: UInt64,
        variant: SudokuVariant,
        difficulty: Difficulty,
    ) -> UUID {
        var mix = SplitMix64(seed: seed ^ EventSeeds.fnv1a("\(variant.slug):\(difficulty.slug)"))
        let high = mix.next()
        let low = mix.next()
        let hex = String(format: "%016llX%016llX", high, low)
        let dashed = [
            hex.prefix(8),
            hex.dropFirst(8).prefix(4),
            hex.dropFirst(12).prefix(4),
            hex.dropFirst(16).prefix(4),
            hex.dropFirst(20),
        ].joined(separator: "-")
        return UUID(uuidString: dashed) ?? UUID()
    }
}
