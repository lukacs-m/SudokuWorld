import Model

/// The fog-of-war session rules. Beginner to Hard play the original
/// mechanic: three seeded 3×3 windows, and a correct digit lifts the 3×3
/// patch around itself. Expert and Master play "fair fog": more windows
/// start visible, a correct digit lifts its whole row, column and box (the
/// peers every advanced technique reads), and whenever the visible position
/// has no logical step within the puzzle's grade the game lifts one more
/// window on its own — so the puzzle stays finishable by logic alone.
enum FogOfWar {
    /// Keyed on the tier the player picked (and the game screen shows);
    /// the never-stuck check is capped at the graded difficulty, the
    /// techniques the puzzle actually needs.
    static func isFair(_ puzzle: PuzzleDefinition) -> Bool {
        puzzle.variant == .fogOfWar && puzzle.requestedDifficulty >= .expert
    }

    static let classicWindowCount = 3
    /// Chosen from the logic-only simulation in `FogOfWarTests`: fewer
    /// windows leave most Expert/Master openings stuck before the first
    /// move, more mostly just shrink the fog.
    static let fairWindowCount = 5

    // MARK: - Starting windows

    /// The windows a fresh game starts with.
    static func initialWindows(for puzzle: PuzzleDefinition) -> Set<Int> {
        guard puzzle.variant == .fogOfWar else { return [] }
        let count = isFair(puzzle) ? fairWindowCount : classicWindowCount
        return seededWindows(for: puzzle, count: count)
    }

    /// The first `count` windows of the puzzle's seeded stream. Windows may
    /// overlap; the stream never changes, so a tier that shows more windows
    /// still starts from the same three as the lower tiers.
    static func seededWindows(for puzzle: PuzzleDefinition, count: Int) -> Set<Int> {
        let size = gridSize(of: puzzle)
        var rng = SplitMix64(seed: puzzle.seed)
        var revealed = Set<Int>()
        for _ in 0 ..< count {
            let originRow = Int(rng.next() % UInt64(size - 2))
            let originCol = Int(rng.next() % UInt64(size - 2))
            revealed.formUnion(window(originRow: originRow, originCol: originCol, size: size))
        }
        return revealed
    }

    // MARK: - Reveal on a correct placement

    /// The cells a correct placement lifts the fog from.
    static func reveal(around index: Int, puzzle: PuzzleDefinition) -> Set<Int> {
        isFair(puzzle) ? houses(of: index, puzzle: puzzle) : neighborhood(of: index, puzzle: puzzle)
    }

    /// The 3×3 patch around a cell (classic mechanic).
    static func neighborhood(of index: Int, puzzle: PuzzleDefinition) -> Set<Int> {
        let size = gridSize(of: puzzle)
        let row = index / size
        let col = index % size
        var cells = Set<Int>()
        for rowDelta in -1 ... 1 {
            for colDelta in -1 ... 1 {
                let neighborRow = row + rowDelta
                let neighborCol = col + colDelta
                guard neighborRow >= 0, neighborRow < size,
                      neighborCol >= 0, neighborCol < size else { continue }
                cells.insert(neighborRow * size + neighborCol)
            }
        }
        return cells
    }

    /// The cell's row, column and 3×3 box (fair fog).
    static func houses(of index: Int, puzzle: PuzzleDefinition) -> Set<Int> {
        let size = gridSize(of: puzzle)
        let row = index / size
        let col = index % size
        var cells = Set<Int>()
        for other in 0 ..< size {
            cells.insert(row * size + other)
            cells.insert(other * size + col)
        }
        cells.formUnion(window(originRow: row / 3 * 3, originCol: col / 3 * 3, size: size))
        return cells
    }

    // MARK: - Never stuck

    /// The visible position: revealed givens plus the player's correct
    /// placements. Every fogged cell — givens included — and every wrong
    /// entry is unknown.
    static func visibleValues(
        board: Board,
        puzzle: PuzzleDefinition,
        revealed: Set<Int>,
    ) -> [Int?] {
        (0 ..< board.count).map { index in
            guard revealed.contains(index), board[index].value == puzzle.solution[index] else {
                return nil
            }
            return board[index].value
        }
    }

    /// The first digit the technique ladder, capped at the puzzle's grade,
    /// places into a visible empty cell from the visible position — or nil
    /// when logic is stuck there. Deductions about fogged cells are allowed
    /// to feed the chain: the player can reason about a hidden cell even
    /// though they cannot write in it.
    static func firstVisiblePlacement(
        puzzle: PuzzleDefinition,
        board: Board,
        revealed: Set<Int>,
        context: SolverContext? = nil,
    ) -> (cell: Int, digit: Int)? {
        let visible = visibleValues(board: board, puzzle: puzzle, revealed: revealed)
        let solver = context ?? solverContext(for: puzzle)
        var grid = SolverGrid(context: solver, givens: visible)
        let cap = Grader.maxRank(for: puzzle.gradedDifficulty)
        while true {
            guard grid.propagate(maxRank: cap) else { return nil }
            for cell in 0 ..< visible.count
                where visible[cell] == nil && revealed.contains(cell) && grid.values[cell] != 0
            {
                return (cell, grid.values[cell])
            }
            guard let step = TechniqueLadder.nextStep(in: grid, cap: cap),
                  step.apply(to: &grid) else { return nil }
        }
    }

    /// Built once per never-stuck run and threaded through every candidate
    /// so the peer and house-pair precomputation is not repeated per solve.
    static func solverContext(for puzzle: PuzzleDefinition) -> SolverContext {
        SolverContext(topology: TopologyFactory.topology(for: puzzle))
    }

    /// How many candidate windows the solver is run against. The scan is
    /// synchronous on the caller's actor and each test is a full capped
    /// solve, so only the best-scoring windows are worth trying.
    static let scannedWindows = 12

    /// The window the never-stuck rule lifts next: candidate windows are
    /// walked in an order seeded from the puzzle seed and the reveal count
    /// (so a restored save makes the same choice), then ranked by how many
    /// hidden givens they expose — hidden givens are what starves logic,
    /// and this measurably needs fewer lifts than taking the first
    /// unlocking window. The best `scannedWindows` are tested, and the
    /// first that unlocks a step wins. When none unlocks (or none is
    /// tested), the first window showing anything new. Empty once the
    /// whole board is visible.
    static func autoReveal(
        puzzle: PuzzleDefinition,
        board: Board,
        revealed: Set<Int>,
        context: SolverContext? = nil,
    ) -> Set<Int> {
        let size = gridSize(of: puzzle)
        var origins: [(row: Int, col: Int)] = []
        for row in 0 ..< (size - 2) {
            for col in 0 ..< (size - 2) {
                origins.append((row, col))
            }
        }
        var rng = Xoshiro256StarStar(
            seed: puzzle.seed ^ (UInt64(revealed.count) &* 0x9E37_79B9_7F4A_7C15),
        )
        origins.shuffle(using: &rng)
        let candidates = origins
            .map { window(originRow: $0.row, originCol: $0.col, size: size) }
            .filter { !$0.isSubset(of: revealed) }
        guard let fallback = candidates.first else { return [] }

        let hiddenGivens: [Int] = candidates.map { cells in
            cells.count { cell in !revealed.contains(cell) && puzzle.givens[cell] != nil }
        }
        // `sorted(by:)` is not guaranteed stable, so the seeded position is
        // part of the key: ties keep the shuffle's order.
        let ranked = candidates.indices.sorted {
            hiddenGivens[$0] == hiddenGivens[$1]
                ? $0 < $1
                : hiddenGivens[$0] > hiddenGivens[$1]
        }
        .prefix(scannedWindows)

        let solver = context ?? solverContext(for: puzzle)
        let unlocking = ranked.first { candidate in
            firstVisiblePlacement(
                puzzle: puzzle,
                board: board,
                revealed: revealed.union(candidates[candidate]),
                context: solver,
            ) != nil
        }
        return unlocking.map { candidates[$0] } ?? fallback
    }

    // MARK: - Geometry

    private static func gridSize(of puzzle: PuzzleDefinition) -> Int {
        Int(Double(puzzle.solution.count).squareRoot())
    }

    private static func window(originRow: Int, originCol: Int, size: Int) -> Set<Int> {
        var cells = Set<Int>()
        for row in originRow ..< (originRow + 3) {
            for col in originCol ..< (originCol + 3) {
                cells.insert(row * size + col)
            }
        }
        return cells
    }
}
