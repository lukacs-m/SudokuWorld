public import Model

/// Grades a puzzle by running the technique ladder to completion and mapping
/// the hardest technique required onto the difficulty scale. Returns nil when
/// the ladder alone cannot finish the puzzle (harder than Master, or
/// inconsistent) — generation then eases the puzzle until it grades, which
/// guarantees every shipped puzzle is fully hint-solvable.
public struct Grader: Sendable {
    public init() {}

    public func grade(
        topology: GridTopology,
        givens: [Int?],
        cages: [Cage] = [],
        parities: [Int: CellParity] = [:],
        relations: [RelationClue] = [],
        thermometers: [[Int]] = [],
        arrows: [Arrow] = [],
        outsideClues: [OutsideClue] = [],
    ) -> Difficulty? {
        let context = SolverContext(
            topology: topology,
            cages: cages,
            parities: parities,
            relations: relations,
            thermometers: thermometers,
            arrows: arrows,
            outsideClues: outsideClues,
        )
        return grade(context: context, givens: givens)
    }

    /// Hybrid grading: bulk propagation (which tracks the ranks it used)
    /// does the volume work, and the ladder is only consulted at stalls for
    /// the advanced techniques. Same difficulty attribution as pure stepping,
    /// at a fraction of the cost — this runs once per carve attempt.
    func grade(context: SolverContext, givens: [Int?]) -> Difficulty? {
        var grid = SolverGrid(context: context, givens: givens)
        guard !grid.isContradicted else { return nil }

        var hardestRank = -1
        while true {
            guard grid.propagate() else { return nil }
            hardestRank = max(hardestRank, grid.propagationHardestRank)
            if grid.isSolved {
                return difficulty(forHardestRank: hardestRank)
            }
            guard let step = TechniqueLadder.nextStep(in: grid) else { return nil }
            hardestRank = max(hardestRank, step.technique.rank)
            guard step.apply(to: &grid) else { return nil }
        }
    }

    /// The hardest technique rank a puzzle of this grade may require —
    /// the upper bound of each band in `difficulty(forHardestRank:)`.
    static func maxRank(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .beginner: Technique.nakedSingle.rank
        case .easy: Technique.hiddenSingle.rank
        case .medium: Technique.cageArithmetic.rank
        case .hard: Technique.xWing.rank
        case .expert: Technique.xyWing.rank
        case .master: Technique.xyChain.rank
        }
    }

    /// Fast capped solvability: can the ladder finish this puzzle using only
    /// techniques allowed at `target`? Equivalent to `grade(...) <= target`
    /// (the ladder always prefers the easiest applicable step, so capping
    /// never alters its choices — a needed-but-capped step just stalls), but
    /// far cheaper: finders above the cap are never even searched, so a
    /// beginner-capped check is little more than a naked-single fixpoint.
    /// A capped-solvable puzzle is ladder-solvable, hence unique.
    func solvesWithin(target: Difficulty, context: SolverContext, givens: [Int?]) -> Bool {
        let cap = Self.maxRank(for: target)
        var grid = SolverGrid(context: context, givens: givens)
        while true {
            guard grid.propagate(maxRank: cap) else { return false }
            if grid.isSolved {
                return true
            }
            guard grid.propagationHardestRank <= cap else { return false }
            guard let step = TechniqueLadder.nextStep(in: grid, cap: cap) else { return false }
            guard step.apply(to: &grid) else { return false }
        }
    }

    /// The rank → difficulty table (see `Technique.rank`). Kept in one place
    /// so tuning the scale never touches the finders. Bands are drawn where
    /// requirements actually cluster at depth: "needs triples/X-wing exactly"
    /// is a razor-thin slice, so it shares the hard band; wings and fish
    /// (common near minimal depth) are expert; chains are master.
    func difficulty(forHardestRank rank: Int) -> Difficulty {
        switch rank {
        case ..<1: .beginner // naked singles only
        case 1: .easy // hidden singles
        case 2 ... 4: .medium // pairs, cage arithmetic
        case 5 ... 9: .hard // locked candidates, bent lines, triples, x-wing
        case 10 ... 11: .expert // swordfish, xy-wing
        default: .master // xy-chains
        }
    }
}
