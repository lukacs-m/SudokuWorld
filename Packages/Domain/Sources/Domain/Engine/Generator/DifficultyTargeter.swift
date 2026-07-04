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
        var graded = grader.grade(context: context, givens: givens)

        while graded == nil || graded.map({ $0 > target }) == true {
            guard let unit = pool.popLast() else { break }
            for cell in unit {
                givens[cell] = solution[cell]
            }
            graded = grader.grade(context: context, givens: givens)

            // Overshot below the target: this unit lowered the grade too far.
            // Try swapping it for another pool unit that lands exactly.
            if let grade = graded, grade < target {
                graded = repairOvershoot(
                    context: context,
                    givens: &givens,
                    pool: &pool,
                    overshotUnit: unit,
                    overshotGrade: grade,
                    solution: solution,
                    target: target,
                    grader: grader,
                )
            }
        }

        guard let final = graded else { return nil }
        return Outcome(givens: givens, graded: final)
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
