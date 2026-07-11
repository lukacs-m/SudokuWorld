import Model

/// Digs givens out of a full solution under two constraints per difficulty:
///
/// - **Technique cap** — a removal is kept only while the technique ladder
///   still solves the puzzle (ladder-solvable implies a unique solution —
///   every deduction is forced) *and* grades at or below the target.
/// - **Givens floor** — digging stops once the clue count reaches the
///   difficulty's minimum, so difficulty is visible on the board.
///
/// The work is deterministically bounded so generation always finishes fast,
/// even on samurai's 369 cells:
///
/// - Removals are attempted in **speculative batches** (one grade check per
///   chunk instead of per cell); a failed batch is retried unit by unit.
/// - Digging stops early after a run of consecutive failed removals — near
///   the minimum, further attempts almost never succeed and each one costs
///   a full solve.
///
/// Works in 180°-symmetric pairs when asked.
enum GivensCarver {
    /// Units speculatively removed per batch grade check.
    private static let batchUnits = 4

    /// Stop digging after this many failed unit removals in a row. Only
    /// applied on large grids, where each rejection costs an expensive full
    /// solve; 9×9-class grids dig exhaustively (their grades are cheap, and
    /// deep targets like master need persistence through rejection runs).
    private static func rejectionLimit(cellCount: Int) -> Int {
        cellCount > 200 ? 12 : Int.max
    }

    struct Result {
        var givens: [Int?]
        /// The grade after carving; nil never escapes (a full board grades
        /// beginner, and only solvable states are kept).
        var graded: Difficulty?
    }

    static func carve(
        context: SolverContext,
        solution: [Int],
        target: Difficulty,
        minimumGivens: Int,
        symmetric: Bool,
        rng: inout Xoshiro256StarStar,
        grader: Grader,
    ) -> Result {
        var givens: [Int?] = solution
        var graded: Difficulty? = .beginner
        var givensCount = context.cellCount
        var consecutiveRejections = 0
        let rejectionLimit = Self.rejectionLimit(cellCount: context.cellCount)

        let units = removalUnits(context: context, symmetric: symmetric, rng: &rng)

        var index = 0
        while index < units.count {
            if givensCount <= minimumGivens { break }
            if consecutiveRejections >= rejectionLimit { break }

            let end = min(index + Self.batchUnits, units.count)
            let batch = Array(units[index ..< end])
            let batchCells = batch.flatMap(\.self)

            // Speculative batch: one grade check for several units.
            if batch.count > 1, givensCount - batchCells.count >= minimumGivens {
                let backup = batchCells.map { givens[$0] }
                for cell in batchCells {
                    givens[cell] = nil
                }
                if let newGrade = grader.grade(context: context, givens: givens),
                   newGrade <= target
                {
                    graded = newGrade
                    givensCount -= batchCells.count
                    consecutiveRejections = 0
                    index = end
                    continue
                }
                for (offset, cell) in batchCells.enumerated() {
                    givens[cell] = backup[offset]
                }
            }

            // Batch failed (or didn't fit the floor): retry its units one by one.
            for unit in batch {
                if givensCount <= minimumGivens { break }
                if consecutiveRejections >= rejectionLimit { break }
                // A symmetric pair may overshoot the floor where a single fits.
                if givensCount - unit.count < minimumGivens { continue }

                let backup = unit.map { givens[$0] }
                for cell in unit {
                    givens[cell] = nil
                }
                if let newGrade = grader.grade(context: context, givens: givens),
                   newGrade <= target
                {
                    graded = newGrade
                    givensCount -= unit.count
                    consecutiveRejections = 0
                } else {
                    for (offset, cell) in unit.enumerated() {
                        givens[cell] = backup[offset]
                    }
                    consecutiveRejections += 1
                }
            }
            index = end
        }
        return Result(givens: givens, graded: graded)
    }

    /// Shuffled removal units: single cells, or 180°-symmetric pairs.
    private static func removalUnits(
        context: SolverContext,
        symmetric: Bool,
        rng: inout Xoshiro256StarStar,
    ) -> [[Int]] {
        let topology = context.topology
        var units: [[Int]] = []
        var grouped = Set<Int>()
        for cell in Array(0 ..< context.cellCount).shuffled(using: &rng)
            where !grouped.contains(cell)
        {
            var unit = [cell]
            grouped.insert(cell)
            if symmetric {
                let position = topology.position(of: cell)
                if let mirror = topology.index(
                    row: topology.rowCount - 1 - position.row,
                    col: topology.colCount - 1 - position.col,
                ), mirror != cell, !grouped.contains(mirror) {
                    unit.append(mirror)
                    grouped.insert(mirror)
                }
            }
            units.append(unit)
        }
        return units
    }
}
