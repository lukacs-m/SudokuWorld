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
    ) -> Difficulty? {
        let context = SolverContext(topology: topology, cages: cages, parities: parities)
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

    /// Fast completeness check: can the ladder finish this puzzle at all?
    /// Bulk propagation (singles + cage arithmetic) does the heavy lifting;
    /// the ladder is only consulted at stalls, skipping per-step bookkeeping.
    /// A fully ladder-solvable puzzle is necessarily unique — every deduction
    /// is forced — which is what lets generation avoid exhaustive
    /// solution counting entirely.
    func solves(context: SolverContext, givens: [Int?]) -> Bool {
        var grid = SolverGrid(context: context, givens: givens)
        while true {
            guard grid.propagate() else { return false }
            if grid.isSolved { return true }
            guard let step = TechniqueLadder.nextStep(in: grid) else { return false }
            guard step.apply(to: &grid) else { return false }
        }
    }

    /// The rank → difficulty table (see `Technique.rank`). Kept in one place
    /// so tuning the scale never touches the finders.
    func difficulty(forHardestRank rank: Int) -> Difficulty {
        switch rank {
        case ..<1: .beginner // naked singles only
        case 1: .easy // hidden singles
        case 2 ... 4: .medium // pairs, cage arithmetic
        case 5 ... 6: .hard // locked candidates
        case 7 ... 8: .expert // triples
        default: .master // x-wing
        }
    }
}
