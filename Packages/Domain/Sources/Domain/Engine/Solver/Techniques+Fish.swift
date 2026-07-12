import Model

extension Techniques {
    /// X-wing: a digit restricted to the same two cover lines in two base
    /// lines forms a rectangle; the digit falls out of the rest of the cover
    /// lines.
    static func xWing(in grid: SolverGrid) -> SolveStep? {
        fish(in: grid, size: 2, technique: .xWing)
    }

    /// Swordfish: the size-3 fish — three base lines whose candidates for a
    /// digit sit inside three cover lines.
    static func swordfish(in grid: SolverGrid) -> SolveStep? {
        fish(in: grid, size: 3, technique: .swordfish)
    }

    /// Generic fish of `size` N: N base lines in which a digit has 2...N
    /// candidate cells, all coverable by N cover lines → the digit falls out
    /// of the cover lines outside the fish. Runs rows→columns then
    /// columns→rows. House-membership driven, so it stays correct on
    /// samurai's overlapping sub-grids (where a cell may sit in two cover
    /// houses).
    private static func fish(in grid: SolverGrid, size: Int, technique: Technique) -> SolveStep? {
        if let step = fish(
            in: grid,
            size: size,
            technique: technique,
            baseKind: .row,
            coverKind: .column,
        ) {
            return step
        }
        return fish(
            in: grid,
            size: size,
            technique: technique,
            baseKind: .column,
            coverKind: .row,
        )
    }

    private static func fish(
        in grid: SolverGrid,
        size: Int,
        technique: Technique,
        baseKind: HouseKind,
        coverKind: HouseKind,
    ) -> SolveStep? {
        let context = grid.context
        let baseHouses = context.houses.indices.filter { context.houseKinds[$0] == baseKind }

        for digit in 1 ... context.size {
            let mask = SolverContext.mask(for: digit)
            var candidateBases: [[Int]] = []
            for house in baseHouses {
                guard grid.housePlacements(house) & mask == 0 else { continue }
                let cells = context.houses[house].filter {
                    grid.values[$0] == 0 && grid.candidates[$0] & mask != 0
                }
                if cells.count >= 2, cells.count <= size {
                    candidateBases.append(cells)
                }
            }
            guard candidateBases.count >= size else { continue }

            for combo in combinations(of: Array(candidateBases.indices), choose: size) {
                let fishCells = combo.flatMap { candidateBases[$0] }
                guard let covers = coverAssignment(
                    for: fishCells,
                    size: size,
                    kind: coverKind,
                    context: context,
                ) else { continue }

                let members = Set(fishCells)
                var eliminations: [(cell: Int, digit: Int)] = []
                for cover in covers {
                    for cell in context.houses[cover]
                        where !members.contains(cell)
                        && grid.values[cell] == 0
                        && grid.candidates[cell] & mask != 0
                    {
                        eliminations.append((cell: cell, digit: digit))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: technique,
                    eliminations: eliminations,
                    focusCells: members.sorted(),
                    focusDigits: [digit],
                )
            }
        }
        return nil
    }

    /// Finds `size` cover houses of `kind` that jointly contain every fish
    /// cell, or nil when no such set exists. Cells carry at most two cover
    /// houses (samurai overlaps), so the candidate pool stays tiny.
    private static func coverAssignment(
        for cells: [Int],
        size: Int,
        kind: HouseKind,
        context: SolverContext,
    ) -> [Int]? {
        var coverOptions: [[Int]] = []
        var pool = Set<Int>()
        for cell in cells {
            let covers = context.housesForCell[cell].filter { context.houseKinds[$0] == kind }
            guard !covers.isEmpty else { return nil }
            coverOptions.append(covers)
            pool.formUnion(covers)
        }
        guard pool.count >= size else { return nil }

        for coverCombo in combinations(of: pool.sorted(), choose: size) {
            let chosen = Set(coverCombo)
            if coverOptions.allSatisfy({ options in
                options.contains { chosen.contains($0) }
            }) {
                return coverCombo
            }
        }
        return nil
    }
}
