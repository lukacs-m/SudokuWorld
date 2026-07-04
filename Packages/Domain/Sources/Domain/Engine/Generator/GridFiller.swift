import Model

/// Produces a complete random solution honoring a topology, via
/// minimum-remaining-values backtracking with seed-shuffled digit orders.
enum GridFiller {
    static func fill(context: SolverContext, rng: inout Xoshiro256StarStar) -> [Int]? {
        var grid = SolverGrid(
            context: context,
            givens: [Int?](repeating: nil, count: context.cellCount),
        )
        return search(&grid, rng: &rng)
    }

    private static func search(
        _ grid: inout SolverGrid,
        rng: inout Xoshiro256StarStar,
    ) -> [Int]? {
        guard grid.propagate() else { return nil }
        if grid.isSolved { return grid.values }
        guard let cell = grid.minimumRemainingCell() else { return nil }

        let digits = grid.context.digits(in: grid.candidates[cell]).shuffled(using: &rng)
        for digit in digits {
            var branch = grid
            guard branch.place(digit, at: cell) else { continue }
            if let solution = search(&branch, rng: &rng) {
                return solution
            }
        }
        return nil
    }
}
