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
        relations: [RelationClue] = [],
        thermometers: [[Int]] = [],
        arrows: [Arrow] = [],
    ) {
        context = SolverContext(
            topology: topology,
            cages: cages,
            parities: parities,
            relations: relations,
            thermometers: thermometers,
            arrows: arrows,
        )
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

    /// Iterative DFS with an explicit frame stack: recursion would go one
    /// frame per placed cell, which overflows the 512 KB cooperative-pool
    /// stacks on 900-cell layouts (sumo). Visit order matches the recursive
    /// formulation (ascending digits), so solve() results are unchanged.
    private func search(
        _ grid: inout SolverGrid,
        limit: Int,
        count: inout Int,
        solution: inout [Int]?,
    ) {
        struct Frame {
            let grid: SolverGrid
            let cell: Int
            var nextDigit = 1
        }
        enum Entry {
            case deadEnd
            case solved
            case frame(Frame)
        }

        /// Inout so propagation mutates uniquely-owned buffers in place; a
        /// by-value parameter would copy every solver array at each node.
        func enter(_ grid: inout SolverGrid) -> Entry {
            guard grid.propagate() else { return .deadEnd }
            if grid.isSolved {
                count += 1
                if solution == nil {
                    solution = grid.values
                }
                return .solved
            }
            guard let cell = grid.minimumRemainingCell() else { return .deadEnd }
            return .frame(Frame(grid: grid, cell: cell))
        }

        var stack: [Frame] = []
        switch enter(&grid) {
        case .deadEnd, .solved: return
        case let .frame(first): stack.append(first)
        }

        while var top = stack.popLast(), count < limit {
            let mask = top.grid.candidates[top.cell]
            var digit: Int?
            while top.nextDigit <= context.size {
                let candidate = top.nextDigit
                top.nextDigit += 1
                if mask & SolverContext.mask(for: candidate) != 0 {
                    digit = candidate
                    break
                }
            }
            guard let digit else { continue }
            stack.append(top)

            var branch = top.grid
            guard branch.place(digit, at: top.cell) else { continue }
            if case let .frame(child) = enter(&branch) {
                stack.append(child)
            }
        }
    }
}
