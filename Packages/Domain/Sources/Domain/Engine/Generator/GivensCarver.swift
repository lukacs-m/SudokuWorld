import Model

/// Digs givens out of a full solution under two constraints per difficulty:
///
/// - **Technique cap** — a removal is kept only while the technique ladder
///   still solves the puzzle (ladder-solvable implies a unique solution —
///   every deduction is forced) *and* grades at or below the target.
/// - **Givens floor** — digging stops once the clue count reaches the
///   difficulty's minimum. Without the floor every difficulty gets carved to
///   its technique limit, which makes even "beginner" boards sparse and
///   human-hard, and makes all difficulties feel alike.
///
/// Works in 180°-symmetric pairs when asked.
enum GivensCarver {
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
        let topology = context.topology
        var givens: [Int?] = solution
        var graded: Difficulty? = .beginner
        var givensCount = context.cellCount

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

        for unit in units {
            if givensCount <= minimumGivens { break }
            // A symmetric pair may overshoot the floor where a single still fits.
            if givensCount - unit.count < minimumGivens { continue }

            let backup = unit.map { givens[$0] }
            for cell in unit {
                givens[cell] = nil
            }
            let newGrade = grader.grade(context: context, givens: givens)
            if let newGrade, newGrade <= target {
                graded = newGrade
                givensCount -= unit.count
            } else {
                for (offset, cell) in unit.enumerated() {
                    givens[cell] = backup[offset]
                }
            }
        }
        return Result(givens: givens, graded: graded)
    }
}
