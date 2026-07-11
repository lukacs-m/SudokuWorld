import Model

/// Tunes carved givens toward a target difficulty. Re-adds removed givens
/// (newest first) until the technique ladder both finishes the puzzle and
/// grades it at or below the target — guaranteeing every shipped puzzle is
/// fully solvable with hints. At full givens the grade is beginner, so the
/// loop always terminates.
enum DifficultyTargeter {
    struct Outcome {
        let givens: [Int?]
        let graded: Difficulty
    }

    static func tune(
        context: SolverContext,
        givens initialGivens: [Int?],
        removedUnits: [[Int]],
        solution: [Int],
        target: Difficulty,
        grader: Grader,
    ) -> Outcome? {
        var givens = initialGivens
        var pool = removedUnits
        var lastAdded: [Int]?

        // Ease with cheap capped solvability checks; the expensive full grade
        // runs once at the end (plus a bounded overshoot repair).
        while !grader.solvesWithin(target: target, context: context, givens: givens) {
            guard let unit = pool.popLast() else {
                // Pool exhausted above the target — label honestly.
                guard let final = grader.grade(context: context, givens: givens) else {
                    return nil
                }
                return Outcome(givens: givens, graded: final)
            }
            for cell in unit {
                givens[cell] = solution[cell]
            }
            lastAdded = unit
        }

        guard var graded = grader.grade(context: context, givens: givens) else { return nil }

        // Overshot below the target: the last added unit lowered the grade
        // too far. Try swapping it for another pool unit that lands exactly.
        // A one-unit swap can only ever bridge one band — repairing a wider
        // gap (e.g. hard-graded killer asked for master) is wasted grading.
        if graded < target, target.rank - graded.rank == 1, let unit = lastAdded {
            graded = repairOvershoot(
                context: context,
                givens: &givens,
                pool: &pool,
                overshotUnit: unit,
                overshotGrade: graded,
                solution: solution,
                target: target,
                grader: grader,
            )
        }
        return Outcome(givens: givens, graded: graded)
    }

    /// Bounded search for an alternative re-add that hits the target exactly.
    /// Falls back to the overshot grade when no swap works.
    private static func repairOvershoot(
        context: SolverContext,
        givens: inout [Int?],
        pool: inout [[Int]],
        overshotUnit: [Int],
        overshotGrade: Difficulty,
        solution: [Int],
        target: Difficulty,
        grader: Grader,
    ) -> Difficulty {
        let attemptBudget = 12
        for cell in overshotUnit {
            givens[cell] = nil
        }

        for poolIndex in pool.indices.reversed().prefix(attemptBudget) {
            let candidate = pool[poolIndex]
            for cell in candidate {
                givens[cell] = solution[cell]
            }
            if grader.grade(context: context, givens: givens) == target {
                pool.remove(at: poolIndex)
                pool.append(overshotUnit)
                return target
            }
            for cell in candidate {
                givens[cell] = nil
            }
        }

        // No exact swap found — restore the overshooting unit and accept.
        for cell in overshotUnit {
            givens[cell] = solution[cell]
        }
        return overshotGrade
    }
}
