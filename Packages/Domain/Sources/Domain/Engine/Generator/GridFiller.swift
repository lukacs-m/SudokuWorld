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

    /// Backtracking on empty grids is heavy-tailed: multi-grid layouts whose
    /// sub-grids couple through a single shared box can bury the search in
    /// one component while the contradiction lives in another. Rather than
    /// ride out a pathological seed, an attempt gets a bounded number of
    /// digit trials — a healthy fill uses barely more than one per cell —
    /// and aborts so the caller's attempt loop reseeds (classic restart
    /// strategy for Las Vegas searches). Deterministic, unlike a wall clock.
    static func trialBudget(cellCount: Int) -> Int {
        60 * cellCount
    }

    /// Iterative DFS with an explicit frame stack: recursion would go one
    /// frame per placed cell, which overflows the 512 KB cooperative-pool
    /// stacks on 900-cell layouts (sumo). Node visit order and rng call
    /// order match the recursive formulation exactly, so seeded output is
    /// byte-identical.
    private static func search(
        _ grid: inout SolverGrid,
        rng: inout Xoshiro256StarStar,
    ) -> [Int]? {
        struct Frame {
            let grid: SolverGrid
            let cell: Int
            let digits: [Int]
            var next = 0
        }
        enum Entry {
            case deadEnd
            case solved([Int])
            case frame(Frame)
        }

        // Takes the grid inout so propagation mutates uniquely-owned buffers
        // in place — a by-value parameter would force a full copy-on-write
        // of every solver array at each node.
        func enter(_ grid: inout SolverGrid) -> Entry {
            guard grid.propagate() else { return .deadEnd }
            if grid.isSolved {
                return .solved(grid.values)
            }
            guard let cell = grid.minimumRemainingCell() else { return .deadEnd }
            let digits = grid.context.digits(in: grid.candidates[cell]).shuffled(using: &rng)
            return .frame(Frame(grid: grid, cell: cell, digits: digits))
        }

        var stack: [Frame] = []
        switch enter(&grid) {
        case .deadEnd: return nil
        case let .solved(values): return values
        case let .frame(first): stack.append(first)
        }

        var trials = 0
        let budget = trialBudget(cellCount: grid.context.cellCount)
        while var top = stack.popLast() {
            guard top.next < top.digits.count else { continue }
            trials += 1
            if trials > budget {
                return nil
            }
            let digit = top.digits[top.next]
            top.next += 1
            stack.append(top)

            var branch = top.grid
            guard branch.place(digit, at: top.cell) else { continue }
            switch enter(&branch) {
            case .deadEnd: continue
            case let .solved(values): return values
            case let .frame(child): stack.append(child)
            }
        }
        return nil
    }
}
