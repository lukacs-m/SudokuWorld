import Model

extension Techniques {
    /// Killer-cage arithmetic: the last open cell of a cage is forced to the
    /// remaining sum, and digits that appear in no combination matching the
    /// remaining sum/count fall out of every open cage cell.
    static func cageArithmetic(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        guard !context.cages.isEmpty else { return nil }

        for (index, cage) in context.cages.enumerated() {
            let state = grid.cageState(index)
            guard state.remainingCount > 0 else { continue }
            let openCells = cage.cells.filter { grid.values[$0] == 0 }

            if state.remainingCount == 1, let cell = openCells.first {
                let digit = state.remainingSum
                guard digit >= 1, digit <= context.size,
                      grid.candidates[cell] & SolverContext.mask(for: digit) != 0
                else { continue }
                return SolveStep(
                    technique: .cageArithmetic,
                    placements: [(cell: cell, digit: digit)],
                    focusCells: cage.cells,
                    focusDigits: [digit],
                )
            }

            let available = context.fullMask & ~state.usedMask
            let usable = CageCombinations.usableDigits(
                count: state.remainingCount,
                sum: state.remainingSum,
                available: available,
                size: context.size,
            )
            var eliminations: [(cell: Int, digit: Int)] = []
            for cell in openCells {
                let extras = grid.candidates[cell] & ~usable
                guard extras != 0 else { continue }
                for digit in context.digits(in: extras) {
                    eliminations.append((cell: cell, digit: digit))
                }
            }
            guard !eliminations.isEmpty else { continue }
            return SolveStep(
                technique: .cageArithmetic,
                eliminations: eliminations,
                focusCells: cage.cells,
                focusDigits: context.digits(in: usable),
            )
        }
        return nil
    }
}
