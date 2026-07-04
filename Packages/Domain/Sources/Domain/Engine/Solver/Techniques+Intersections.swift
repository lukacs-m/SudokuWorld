import Model

extension Techniques {
    /// Locked candidates over any pair of intersecting houses: when a digit's
    /// candidates in the source house all sit inside the overlap with a target
    /// house, the digit cannot appear elsewhere in the target. Covers pointing
    /// pairs (box → line) and box-line reduction (line → box), and generalizes
    /// to windoku windows and diagonals for free.
    static func lockedCandidates(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        for pair in context.housePairs {
            let placed = grid.housePlacements(pair.source)
            for digit in 1 ... context.size {
                let mask = SolverContext.mask(for: digit)
                guard placed & mask == 0 else { continue }

                let sourceCells = context.houses[pair.source].filter {
                    grid.values[$0] == 0 && grid.candidates[$0] & mask != 0
                }
                // A single home would be a hidden single, found earlier.
                guard sourceCells.count >= 2 else { continue }
                guard sourceCells.allSatisfy({ pair.sharedCells.contains($0) }) else { continue }

                var eliminations: [(cell: Int, digit: Int)] = []
                for cell in context.houses[pair.target]
                    where !pair.sharedCells.contains(cell)
                    && grid.values[cell] == 0
                    && grid.candidates[cell] & mask != 0
                {
                    eliminations.append((cell: cell, digit: digit))
                }
                guard !eliminations.isEmpty else { continue }

                let sourceKind = context.houseKinds[pair.source]
                let boxLike = sourceKind == .box || sourceKind == .window
                return SolveStep(
                    technique: boxLike ? .pointingPair : .boxLineReduction,
                    eliminations: eliminations,
                    focusCells: sourceCells,
                    focusDigits: [digit],
                )
            }
        }
        return nil
    }
}
