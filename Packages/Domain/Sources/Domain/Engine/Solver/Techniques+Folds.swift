import Model

extension Techniques {
    /// Locked candidates across a fold (cube, tredoku): a face must hold
    /// every digit, so when a digit's candidates in a face all sit on one
    /// line that continues over the fold, the digit cannot appear in that
    /// line's continuation on the neighbouring face. Only this direction is
    /// sound: a bent line is a clique, not a house, so a digit confined to
    /// one face *on the line* need not be on the line at all.
    static func bentLineLock(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        for pair in context.foldPairs {
            let placed = grid.housePlacements(pair.face)
            for digit in 1 ... context.size {
                let mask = SolverContext.mask(for: digit)
                guard placed & mask == 0 else { continue }

                let faceCells = context.houses[pair.face].filter {
                    grid.values[$0] == 0 && grid.candidates[$0] & mask != 0
                }
                // A single home would be a hidden single, found earlier.
                guard faceCells.count >= 2 else { continue }
                guard faceCells.allSatisfy({ pair.lineCells.contains($0) }) else { continue }

                let eliminations = pair.continuation
                    .filter { grid.values[$0] == 0 && grid.candidates[$0] & mask != 0 }
                    .map { (cell: $0, digit: digit) }
                guard !eliminations.isEmpty else { continue }

                return SolveStep(
                    technique: .bentLine,
                    eliminations: eliminations,
                    focusCells: faceCells,
                    focusDigits: [digit],
                )
            }
        }
        return nil
    }
}
