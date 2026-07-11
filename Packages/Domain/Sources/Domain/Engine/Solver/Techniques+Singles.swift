import Model

extension Techniques {
    /// A cell whose candidates collapsed to one digit.
    static func nakedSingle(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        for cell in 0 ..< context.cellCount where grid.values[cell] == 0 {
            let mask = grid.candidates[cell]
            guard mask.nonzeroBitCount == 1 else { continue }
            let digit = mask.trailingZeroBitCount + 1
            return SolveStep(
                technique: .nakedSingle,
                placements: [(cell: cell, digit: digit)],
                focusCells: [cell],
                focusDigits: [digit],
            )
        }
        return nil
    }

    /// A digit with exactly one possible home in a house.
    static func hiddenSingle(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        for houseIndex in context.houses.indices {
            let placed = grid.housePlacements(houseIndex)
            for digit in 1 ... context.size {
                let mask = SolverContext.mask(for: digit)
                guard placed & mask == 0 else { continue }

                var home: Int?
                var count = 0
                for cell in context.houses[houseIndex]
                    where grid.values[cell] == 0 && grid.candidates[cell] & mask != 0
                {
                    home = cell
                    count += 1
                    if count > 1 {
                        break
                    }
                }
                guard count == 1, let cell = home else { continue }
                return SolveStep(
                    technique: .hiddenSingle,
                    placements: [(cell: cell, digit: digit)],
                    focusCells: [cell],
                    focusDigits: [digit],
                )
            }
        }
        return nil
    }
}
