import Model

extension Techniques {
    /// Naked pair/triple: k cells in a house sharing exactly k candidate
    /// digits between them lock those digits out of the rest of the house.
    static func nakedSubset(in grid: SolverGrid, subsetSize: Int) -> SolveStep? {
        let context = grid.context
        for houseIndex in context.houses.indices {
            let unsolved = context.houses[houseIndex].filter { grid.values[$0] == 0 }
            guard unsolved.count > subsetSize else { continue }

            let eligible = unsolved.filter {
                let count = grid.candidates[$0].nonzeroBitCount
                return count >= 2 && count <= subsetSize
            }
            for combo in combinations(of: eligible, choose: subsetSize) {
                let union = combo.reduce(DigitMask(0)) { $0 | grid.candidates[$1] }
                guard union.nonzeroBitCount == subsetSize else { continue }

                var eliminations: [(cell: Int, digit: Int)] = []
                for cell in unsolved where !combo.contains(cell) {
                    let overlap = grid.candidates[cell] & union
                    guard overlap != 0 else { continue }
                    for digit in context.digits(in: overlap) {
                        eliminations.append((cell: cell, digit: digit))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: subsetSize == 2 ? .nakedPair : .nakedTriple,
                    eliminations: eliminations,
                    focusCells: combo,
                    focusDigits: context.digits(in: union),
                )
            }
        }
        return nil
    }

    /// Hidden pair/triple: k digits confined to the same k cells of a house
    /// strip every other candidate from those cells.
    static func hiddenSubset(in grid: SolverGrid, subsetSize: Int) -> SolveStep? {
        let context = grid.context
        for houseIndex in context.houses.indices {
            let placed = grid.housePlacements(houseIndex)
            let unsolved = context.houses[houseIndex].filter { grid.values[$0] == 0 }
            guard unsolved.count > subsetSize else { continue }

            var positionsForDigit: [Int: [Int]] = [:]
            for digit in 1 ... context.size {
                let mask = SolverContext.mask(for: digit)
                guard placed & mask == 0 else { continue }
                let homes = unsolved.filter { grid.candidates[$0] & mask != 0 }
                if homes.count >= 2, homes.count <= subsetSize {
                    positionsForDigit[digit] = homes
                }
            }
            let eligibleDigits = positionsForDigit.keys.sorted()
            guard eligibleDigits.count >= subsetSize else { continue }

            for digitCombo in combinations(of: eligibleDigits, choose: subsetSize) {
                var cellUnion = Set<Int>()
                for digit in digitCombo {
                    cellUnion.formUnion(positionsForDigit[digit] ?? [])
                }
                guard cellUnion.count == subsetSize else { continue }

                let comboMask = digitCombo.reduce(DigitMask(0)) { $0 | SolverContext.mask(for: $1) }
                var eliminations: [(cell: Int, digit: Int)] = []
                for cell in cellUnion {
                    let extras = grid.candidates[cell] & ~comboMask
                    guard extras != 0 else { continue }
                    for digit in context.digits(in: extras) {
                        eliminations.append((cell: cell, digit: digit))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: subsetSize == 2 ? .hiddenPair : .hiddenTriple,
                    eliminations: eliminations,
                    focusCells: cellUnion.sorted(),
                    focusDigits: digitCombo,
                )
            }
        }
        return nil
    }
}
