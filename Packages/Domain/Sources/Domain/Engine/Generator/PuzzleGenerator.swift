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
    /// boards where every attempt is ~5× more expensive, tighter still for
    /// shogun/sumo-size layouts.
    static func attemptBudget(cellCount: Int) -> Int {
        switch cellCount {
        case ...200: 40
        case ...600: 3
        default: 2
        }
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

    /// Everything shared by the attempts of one generation run.
    struct Plan {
        let topology: GridTopology
        let fillContext: SolverContext
        let variant: SudokuVariant
        let difficulty: Difficulty
        let seed: UInt64
        let grader: Grader
    }

    /// Synchronous core — exposed for tests and for callers already off-main.
    public func generateNow(
        variant: SudokuVariant,
        difficulty: Difficulty,
        seed: UInt64,
    ) -> PuzzleDefinition {
        let topology = TopologyFactory.topology(for: variant)
        // Variants that derive marks (kropki/XV/…) fill unconstrained: the
        // marks are read off the finished solution, so "no mark yet" must
        // not be treated as the negative convention. Miracle's rules are
        // global and DO constrain the fill.
        let plan = Plan(
            topology: topology,
            fillContext: SolverContext(
                topology: topology,
                expandsNegativeConvention: !Self.derivesRelationMarks(variant),
            ),
            variant: variant,
            difficulty: difficulty,
            seed: seed,
            grader: Grader(),
        )

        let maxAttempts = Self.attemptBudget(cellCount: topology.cellCount)
        let (exactPhase, nearPhase) = Self.settlePhases(
            difficulty: difficulty,
            cellCount: topology.cellCount,
            maxAttempts: maxAttempts,
        )

        var attemptSeed = seed
        var best: (puzzle: PuzzleDefinition, distance: Int)?

        for attemptIndex in 0 ..< maxAttempts {
            if let candidate = attempt(plan: plan, attemptSeed: attemptSeed) {
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
        return lastResortPuzzle(plan: plan)
    }

    /// Settle phases per tier: after `exact` attempts a neighboring grade is
    /// acceptable, after `near` a two-off grade. Beginner–medium hunt their
    /// exact grade through the whole budget (attempts are cheap and hits
    /// reliable, thanks to hardening). Hard and expert are the thin bands —
    /// a dig often jumps from "pairs suffice" straight to "needs chains" —
    /// so they get a real hunt before settling on a neighbor. Master hits
    /// reliably and settles fast. Large grids settle fastest — their
    /// attempts are ~5× the cost.
    static func settlePhases(
        difficulty: Difficulty,
        cellCount: Int,
        maxAttempts: Int,
    ) -> (exact: Int, near: Int) {
        if cellCount > 200 {
            (max(1, maxAttempts / 3), max(2, (maxAttempts * 2) / 3))
        } else if difficulty == .hard || difficulty == .expert {
            (4, 8)
        } else if difficulty == .master {
            (2, 4)
        } else {
            (maxAttempts, maxAttempts)
        }
    }
}

// MARK: - Attempt internals

extension PuzzleGenerator {
    /// Variants whose relation marks are derived from the finished solution
    /// (as opposed to miracle, whose rules exist before any solution).
    static func derivesRelationMarks(_ variant: SudokuVariant) -> Bool {
        switch variant {
        case .greaterThan, .kropki, .xv, .consecutive: true
        default: false
        }
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

    /// Everything one variant layers on top of the bare solution.
    private struct Artifacts {
        var outcome: DifficultyTargeter.Outcome?
        var cages: [Cage] = []
        var parities: [Int: CellParity] = [:]
        var relations: [RelationClue] = []
        var thermometers: [[Int]] = []
        var arrows: [Arrow] = []
        var outsideClues: [OutsideClue] = []
    }

    private func attempt(plan: Plan, attemptSeed: UInt64) -> PuzzleDefinition? {
        var rng = Xoshiro256StarStar(seed: attemptSeed)

        // Jigsaw regions are per-puzzle structure: each attempt draws a new
        // partition, so a hard-to-fill layout just costs one retry.
        var topology = plan.topology
        var fillContext = plan.fillContext
        var irregularBoxes: [Int]?
        if plan.variant == .jigsaw {
            let boxes = RegionPartitioner.partition(size: topology.size, rng: &rng)
            irregularBoxes = boxes
            topology = JigsawTopology.build(boxes: boxes)
            fillContext = SolverContext(topology: topology)
        }

        guard let solution = GridFiller.fill(context: fillContext, rng: &rng) else {
            return nil
        }
        let artifacts = makeArtifacts(
            plan: plan,
            topology: topology,
            solution: solution,
            rng: &rng,
        )
        guard let outcome = artifacts.outcome else { return nil }

        return PuzzleDefinition(
            id: Self.deterministicID(
                seed: plan.seed,
                variant: plan.variant,
                difficulty: plan.difficulty,
            ),
            variant: plan.variant,
            requestedDifficulty: plan.difficulty,
            gradedDifficulty: outcome.graded,
            seed: plan.seed,
            givens: outcome.givens,
            solution: solution,
            cages: artifacts.cages,
            parities: artifacts.parities,
            irregularBoxes: irregularBoxes,
            relations: artifacts.relations,
            thermometers: artifacts.thermometers,
            arrows: artifacts.arrows,
            outsideClues: artifacts.outsideClues,
        )
    }

    /// Applies the variant's extras (cages, marks, lines, clues) and carves
    /// the givens accordingly.
    private func makeArtifacts(
        plan: Plan,
        topology: GridTopology,
        solution: [Int],
        rng: inout Xoshiro256StarStar,
    ) -> Artifacts {
        var artifacts = Artifacts()
        let floorScale = deriveMarks(
            into: &artifacts,
            plan: plan,
            topology: topology,
            solution: solution,
            rng: &rng,
        )

        // Killer boards grow their clues from zero instead of carving down.
        if plan.variant.usesCages {
            artifacts.outcome = killerGivens(
                topology: topology,
                cages: artifacts.cages,
                relations: artifacts.relations,
                solution: solution,
                target: plan.difficulty,
                grader: plan.grader,
                rng: &rng,
            )
            return artifacts
        }

        let context = SolverContext(
            topology: topology,
            parities: artifacts.parities,
            relations: artifacts.relations,
            thermometers: artifacts.thermometers,
            arrows: artifacts.arrows,
            outsideClues: artifacts.outsideClues,
        )
        artifacts.outcome = carveAndTune(
            context: context,
            solution: solution,
            difficulty: plan.difficulty,
            grader: plan.grader,
            rng: &rng,
            givensFloorScale: floorScale,
        )
        return artifacts
    }

    /// Derives the variant's visible marks into `artifacts` and returns the
    /// givens-floor scale: variants whose information lives in their marks
    /// carve much sparser than the classic density.
    private func deriveMarks(
        into artifacts: inout Artifacts,
        plan: Plan,
        topology: GridTopology,
        solution: [Int],
        rng: inout Xoshiro256StarStar,
    ) -> Double {
        switch plan.variant {
        case .sandwich, .skyscraper, .littleKiller:
            artifacts.outsideClues = Self.outsideClues(
                variant: plan.variant,
                topology: topology,
                solution: solution,
                difficulty: plan.difficulty,
                rng: &rng,
            )
            return 0.55

        case .thermo:
            artifacts.thermometers = LinePlacer.thermometers(
                topology: topology,
                solution: solution,
                difficulty: plan.difficulty,
                rng: &rng,
            )
            return 0.55

        case .arrow:
            artifacts.arrows = LinePlacer.arrows(
                topology: topology,
                solution: solution,
                difficulty: plan.difficulty,
                rng: &rng,
            )
            return 0.55

        case .greaterThan, .kropki, .xv, .consecutive, .miracle:
            artifacts.relations = RelationMarks.derive(
                variant: plan.variant,
                topology: topology,
                solution: solution,
                rng: &rng,
            )
            return 0.3

        case .killer, .killerGT:
            artifacts.cages = CagePartitioner.partition(
                topology: topology,
                solution: solution,
                difficulty: plan.difficulty,
                rng: &rng,
            )
            if plan.variant == .killerGT {
                // The combo: inequality marks on every orthogonally adjacent
                // in-cage pair, read from the larger value.
                artifacts.relations = Self.inCageInequalities(
                    cages: artifacts.cages,
                    topology: topology,
                    solution: solution,
                )
            }
            return 1

        case .evenOdd:
            artifacts.parities = parityMarks(
                topology: topology,
                solution: solution,
                difficulty: plan.difficulty,
                rng: &rng,
            )
            return 1

        default:
            return 1
        }
    }

    /// Clue sets read off the finished solution. Sandwich shows every row
    /// (left) and column (top) sum, skyscraper all four edges, and little
    /// killer a seeded handful of diagonals.
    private static func outsideClues(
        variant: SudokuVariant,
        topology: GridTopology,
        solution: [Int],
        difficulty: Difficulty,
        rng: inout Xoshiro256StarStar,
    ) -> [OutsideClue] {
        let size = topology.size
        switch variant {
        case .sandwich:
            let spots = (0 ..< size).map { (OutsideClue.Side.leading, $0) }
                + (0 ..< size).map { (OutsideClue.Side.top, $0) }
            return OutsideClues.derive(
                kind: .sandwichSum,
                clues: spots,
                topology: topology,
                solution: solution,
            )

        case .skyscraper:
            let spots = (0 ..< size).flatMap { offset in
                [
                    (OutsideClue.Side.leading, offset),
                    (OutsideClue.Side.trailing, offset),
                    (OutsideClue.Side.top, offset),
                    (OutsideClue.Side.bottom, offset),
                ]
            }
            return OutsideClues.derive(
                kind: .skyscraperCount,
                clues: spots,
                topology: topology,
                solution: solution,
            )

        case .littleKiller:
            let count = switch difficulty {
            case .beginner, .easy: 10
            case .medium, .hard: 8
            case .expert, .master: 7
            }
            var spots: [(OutsideClue.Side, Int)] = []
            for side in [OutsideClue.Side.top, .trailing, .bottom, .leading] {
                for offset in 1 ..< size {
                    spots.append((side, offset))
                }
            }
            spots.shuffle(using: &rng)
            return OutsideClues.derive(
                kind: .diagonalSum,
                clues: Array(spots.prefix(count)),
                topology: topology,
                solution: solution,
            )

        default:
            return []
        }
    }

    private func carveAndTune(
        context: SolverContext,
        solution: [Int],
        difficulty: Difficulty,
        grader: Grader,
        rng: inout Xoshiro256StarStar,
        givensFloorScale: Double = 1,
    ) -> DifficultyTargeter.Outcome? {
        // Symmetry is an aesthetic for approachable boards; expert/master
        // digs need the freedom of single-cell removals to reach the deep,
        // technique-heavy configurations their grades require.
        let request = GivensCarver.Request(
            context: context,
            solution: solution,
            target: difficulty,
            minimumGivens: Int(Double(Self.minimumGivens(
                for: difficulty,
                cellCount: context.cellCount,
            )) * givensFloorScale),
            hardeningFloor: Int(Double(Self.hardeningFloor(
                for: difficulty,
                cellCount: context.cellCount,
            )) * givensFloorScale),
            symmetric: difficulty <= .hard,
        )
        let carved = GivensCarver.carve(request, grader: grader, rng: &rng)
        guard let graded = carved.graded else { return nil }
        return DifficultyTargeter.Outcome(givens: carved.givens, graded: graded)
    }

    /// Inequality marks between orthogonally adjacent cells of one cage,
    /// oriented from the larger solution value.
    static func inCageInequalities(
        cages: [Cage],
        topology: GridTopology,
        solution: [Int],
    ) -> [RelationClue] {
        var cageIndex = [Int](repeating: -1, count: topology.cellCount)
        for (index, cage) in cages.enumerated() {
            for cell in cage.cells {
                cageIndex[cell] = index
            }
        }
        return RelationExpansion.orthogonalPairs(in: topology).compactMap { a, b in
            guard cageIndex[a] >= 0, cageIndex[a] == cageIndex[b] else { return nil }
            return solution[a] > solution[b]
                ? RelationClue(a: a, b: b, kind: .greaterThan)
                : RelationClue(a: b, b: a, kind: .greaterThan)
        }
    }

    /// Killer puzzles start with no givens at all; clues are added one at a
    /// time until the technique ladder can finish the puzzle (which also
    /// guarantees uniqueness), difficulty-tuned, then topped up to the
    /// difficulty's givens floor so easier killers stay approachable.
    private func killerGivens(
        topology: GridTopology,
        cages: [Cage],
        relations: [RelationClue] = [],
        solution: [Int],
        target: Difficulty,
        grader: Grader,
        rng: inout Xoshiro256StarStar,
    ) -> DifficultyTargeter.Outcome? {
        let context = SolverContext(topology: topology, cages: cages, relations: relations)
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
    private func lastResortPuzzle(plan: Plan) -> PuzzleDefinition {
        var rng = Xoshiro256StarStar(seed: plan.seed)
        let solution = GridFiller.fill(context: plan.fillContext, rng: &rng)
            ?? Array(repeating: 1, count: plan.topology.cellCount)
        var givens: [Int?] = solution
        // Leave a token challenge: blank one cell per house where possible.
        for house in plan.topology.houses {
            if let cell = house.first(where: { givens[$0] != nil }) {
                givens[cell] = nil
            }
        }
        let graded = plan.grader.grade(topology: plan.topology, givens: givens) ?? .beginner
        return PuzzleDefinition(
            id: Self.deterministicID(
                seed: plan.seed,
                variant: plan.variant,
                difficulty: plan.difficulty,
            ),
            variant: plan.variant,
            requestedDifficulty: plan.difficulty,
            gradedDifficulty: graded,
            seed: plan.seed,
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
