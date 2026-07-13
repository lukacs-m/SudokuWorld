import Model

extension Techniques {
    /// Arrow/sum-line arithmetic: the target is boxed into the shaft's
    /// reachable sum range, and each shaft cell into what the target leaves
    /// after the other cells' extremes. Mirrors
    /// `SolverGrid.propagateSumLines` one step at a time for hints.
    static func arrowArithmetic(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        guard !context.sumLines.isEmpty else { return nil }

        for line in context.sumLines {
            var shaftMin = 0
            var shaftMax = 0
            for cell in line.cells {
                shaftMin += minCandidate(of: cell, in: grid)
                shaftMax += maxCandidate(of: cell, in: grid)
            }
            var focus = line.cells

            let targetMin: Int
            let targetMax: Int
            switch line.target {
            case let .fixed(total):
                targetMin = total
                targetMax = total
            case let .cell(target):
                focus.append(target)
                if grid.values[target] == 0 {
                    if let step = pruneStep(
                        grid: grid,
                        cell: target,
                        range: shaftMin ... max(shaftMin, shaftMax),
                        focus: focus,
                    ) {
                        return step
                    }
                }
                targetMin = minCandidate(of: target, in: grid)
                targetMax = maxCandidate(of: target, in: grid)
            }

            for cell in line.cells where grid.values[cell] == 0 {
                let othersMin = shaftMin - minCandidate(of: cell, in: grid)
                let othersMax = shaftMax - maxCandidate(of: cell, in: grid)
                if let step = pruneStep(
                    grid: grid,
                    cell: cell,
                    range: (targetMin - othersMax) ... max(
                        targetMin - othersMax,
                        targetMax - othersMin,
                    ),
                    focus: focus,
                ) {
                    return step
                }
            }
        }
        return nil
    }

    private static func pruneStep(
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
            technique: .arrowArithmetic,
            eliminations: digits.map { (cell: cell, digit: $0) },
            focusCells: focus,
            focusDigits: digits,
        )
    }

    private static func minCandidate(of cell: Int, in grid: SolverGrid) -> Int {
        grid.values[cell] != 0
            ? grid.values[cell]
            : grid.candidates[cell].trailingZeroBitCount + 1
    }

    private static func maxCandidate(of cell: Int, in grid: SolverGrid) -> Int {
        grid.values[cell] != 0
            ? grid.values[cell]
            : DigitMask.bitWidth - grid.candidates[cell].leadingZeroBitCount
    }
}
