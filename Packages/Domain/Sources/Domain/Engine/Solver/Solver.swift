public import Model

/// Backtracking solver over any topology: constraint propagation (naked
/// singles + cage arithmetic) plus minimum-remaining-values branching.
/// Serves as the uniqueness checker (`solutionCount(limit: 2)`) and as the
/// ground-truth solver for generation.
public struct Solver: Sendable {
    private let context: SolverContext
    private let givens: [Int?]

    public init(
        topology: GridTopology,
        givens: [Int?],
        cages: [Cage] = [],
        parities: [Int: CellParity] = [:],
    ) {
        context = SolverContext(topology: topology, cages: cages, parities: parities)
        self.givens = givens
    }

    init(context: SolverContext, givens: [Int?]) {
        self.context = context
        self.givens = givens
    }

    /// The first solution in deterministic (ascending digit) order, or nil.
    public func solve() -> [Int]? {
        var count = 0
        var solution: [Int]?
        var grid = SolverGrid(context: context, givens: givens)
        search(&grid, limit: 1, count: &count, solution: &solution)
        return solution
    }

    /// Counts solutions up to `limit` and stops early — `solutionCount(limit: 2)`
    /// is the uniqueness check used throughout generation.
    public func solutionCount(limit: Int) -> Int {
        var count = 0
        var solution: [Int]?
        var grid = SolverGrid(context: context, givens: givens)
        search(&grid, limit: limit, count: &count, solution: &solution)
        return count
    }

    private func search(
        _ grid: inout SolverGrid,
        limit: Int,
        count: inout Int,
        solution: inout [Int]?,
    ) {
        guard grid.propagate() else { return }
        if grid.isSolved {
            count += 1
            if solution == nil {
                solution = grid.values
            }
            return
        }
        guard let cell = grid.minimumRemainingCell() else { return }

        let mask = grid.candidates[cell]
        for digit in 1 ... context.size where mask & SolverContext.mask(for: digit) != 0 {
            var branch = grid
            guard branch.place(digit, at: cell) else { continue }
            search(&branch, limit: limit, count: &count, solution: &solution)
            if count >= limit { return }
        }
    }
}
