import Model

extension Techniques {
    /// X-wing: a digit restricted to the same two cover lines in two base
    /// lines forms a rectangle; the digit falls out of the rest of the cover
    /// lines. Runs rows→columns then columns→rows. House-membership driven,
    /// so it stays correct on samurai's overlapping sub-grids.
    static func xWing(in grid: SolverGrid) -> SolveStep? {
        if let step = xWing(in: grid, baseKind: .row, coverKind: .column) {
            return step
        }
        return xWing(in: grid, baseKind: .column, coverKind: .row)
    }

    private static func xWing(
        in grid: SolverGrid,
        baseKind: HouseKind,
        coverKind: HouseKind,
    ) -> SolveStep? {
        let context = grid.context
        let baseHouses = context.houses.indices.filter { context.houseKinds[$0] == baseKind }

        for digit in 1 ... context.size {
            let mask = SolverContext.mask(for: digit)
            var candidatePairs: [(house: Int, cells: [Int])] = []
            for house in baseHouses {
                guard grid.housePlacements(house) & mask == 0 else { continue }
                let cells = context.houses[house].filter {
                    grid.values[$0] == 0 && grid.candidates[$0] & mask != 0
                }
                if cells.count == 2 {
                    candidatePairs.append((house: house, cells: cells))
                }
            }
            guard candidatePairs.count >= 2 else { continue }

            for combo in combinations(of: Array(candidatePairs.indices), choose: 2) {
                let first = candidatePairs[combo[0]]
                let second = candidatePairs[combo[1]]
                guard let (coverA, coverB) = coverHouses(
                    for: first.cells,
                    and: second.cells,
                    kind: coverKind,
                    context: context,
                ) else { continue }

                let corners = Set(first.cells + second.cells)
                var eliminations: [(cell: Int, digit: Int)] = []
                for cover in [coverA, coverB] {
                    for cell in context.houses[cover]
                        where !corners.contains(cell)
                        && grid.values[cell] == 0
                        && grid.candidates[cell] & mask != 0
                    {
                        eliminations.append((cell: cell, digit: digit))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: .xWing,
                    eliminations: eliminations,
                    focusCells: corners.sorted(),
                    focusDigits: [digit],
                )
            }
        }
        return nil
    }

    /// Matches the two cells of each base line into two shared cover houses
    /// (straight or crossed), or nil when they don't align into a rectangle.
    private static func coverHouses(
        for firstCells: [Int],
        and secondCells: [Int],
        kind: HouseKind,
        context: SolverContext,
    ) -> (Int, Int)? {
        func covers(_ cell: Int) -> Set<Int> {
            Set(context.housesForCell[cell].filter { context.houseKinds[$0] == kind })
        }

        let pairings = [
            (firstCells[0], secondCells[0], firstCells[1], secondCells[1]),
            (firstCells[0], secondCells[1], firstCells[1], secondCells[0]),
        ]
        for (a1, b1, a2, b2) in pairings {
            let coverA = covers(a1).intersection(covers(b1))
            let coverB = covers(a2).intersection(covers(b2))
            if let houseA = coverA.sorted().first,
               let houseB = coverB.sorted().first,
               houseA != houseB
            {
                return (houseA, houseB)
            }
        }
        return nil
    }
}
