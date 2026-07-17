import Model

extension Techniques {
    /// Edge-clue analysis, one step at a time for hints: skyscraper distance
    /// caps (with the clue-1 and clue-N exact specials) and sandwich crust
    /// placement. Mirrors `SolverGrid.propagateOutsideClues`.
    static func outsideClueAnalysis(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        guard !context.outsideLines.isEmpty else { return nil }

        for line in context.outsideLines {
            let step: SolveStep? = switch line.clue.kind {
            case .skyscraperCount:
                skyscraperStep(grid: grid, clue: line.clue, cells: line.cells)

            case .sandwichSum:
                sandwichStep(grid: grid, clue: line.clue, cells: line.cells)

            case .diagonalSum:
                nil // surfaced through arrowArithmetic's sum lines
            }
            if let step {
                return step
            }
        }
        return nil
    }

    private static func skyscraperStep(
        grid: SolverGrid,
        clue: OutsideClue,
        cells: [Int],
    ) -> SolveStep? {
        let context = grid.context
        // Exact specials: clue 1 pins the tallest to the edge; clue `size`
        // forces the whole line ascending.
        if clue.value == 1, grid.values[cells[0]] == 0,
           let step = keepStep(
               grid: grid,
               cell: cells[0],
               range: context.size ... context.size,
               focus: cells,
           )
        {
            return step
        }
        if clue.value == context.size {
            for (distance, cell) in cells.enumerated() where grid.values[cell] == 0 {
                if let step = keepStep(
                    grid: grid,
                    cell: cell,
                    range: (distance + 1) ... (distance + 1),
                    focus: cells,
                ) {
                    return step
                }
            }
        }
        for (distance, cell) in cells.enumerated() where grid.values[cell] == 0 {
            let cap = context.size - clue.value + 1 + distance
            guard cap < context.size else { break }
            if let step = keepStep(grid: grid, cell: cell, range: 1 ... cap, focus: cells) {
                return step
            }
        }
        return nil
    }

    private static func keepStep(
        grid: SolverGrid,
        cell: Int,
        range: ClosedRange<Int>,
        focus: [Int],
    ) -> SolveStep? {
        let context = grid.context
        let low = max(1, range.lowerBound)
        let high = min(context.size, range.upperBound)
        var keep: DigitMask = 0
        if low <= high {
            for digit in low ... high {
                keep |= SolverContext.mask(for: digit)
            }
        }
        let removed = grid.candidates[cell] & ~keep
        guard removed != 0 else { return nil }
        let digits = context.digits(in: removed)
        return SolveStep(
            technique: .outsideClueAnalysis,
            eliminations: digits.map { (cell: cell, digit: $0) },
            focusCells: focus,
            focusDigits: digits,
        )
    }

    private static func sandwichStep(
        grid: SolverGrid,
        clue: OutsideClue,
        cells: [Int],
    ) -> SolveStep? {
        let context = grid.context
        let size = context.size

        func mayHost(_ mask: DigitMask, at index: Int) -> Bool {
            grid.values[cells[index]] == 0
                ? grid.candidates[cells[index]] & mask != 0
                : SolverContext.mask(for: grid.values[cells[index]]) & mask != 0
        }
        func feasible(_ a: Int, _ b: Int) -> Bool {
            let betweenCount = abs(a - b) - 1
            guard betweenCount > 0 else { return clue.value == 0 }
            guard betweenCount <= size - 2 else { return false }
            return clue.value >= betweenCount * (betweenCount + 3) / 2
                && clue.value <= betweenCount * (2 * size - betweenCount - 1) / 2
        }

        let oneMask = SolverContext.mask(for: 1)
        let topMask = SolverContext.mask(for: size)
        for (mask, partnerMask, digit) in [(oneMask, topMask, 1), (topMask, oneMask, size)] {
            for index in cells.indices
                where grid.values[cells[index]] == 0 && mayHost(mask, at: index)
            {
                let hasPartner = cells.indices.contains { partner in
                    partner != index && mayHost(partnerMask, at: partner)
                        && feasible(index, partner)
                }
                if !hasPartner {
                    return SolveStep(
                        technique: .outsideClueAnalysis,
                        eliminations: [(cell: cells[index], digit: digit)],
                        focusCells: cells,
                        focusDigits: [digit],
                    )
                }
            }
        }
        return nil
    }
}
