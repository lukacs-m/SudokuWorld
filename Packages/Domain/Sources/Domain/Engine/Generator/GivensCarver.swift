import Model

/// Digs givens out of a full solution, grade-guided: a removal is kept only
/// while the puzzle stays ladder-solvable (which guarantees a unique
/// solution — every deduction is forced) *and* graded at or below the target
/// difficulty. Digging both stops before overshooting hard targets and keeps
/// pushing until easy targets actually reach their band. Works in
/// 180°-symmetric pairs when asked.
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
        symmetric: Bool,
        rng: inout Xoshiro256StarStar,
        grader: Grader,
    ) -> Result {
        let topology = context.topology
        var givens: [Int?] = solution
        var graded: Difficulty? = .beginner

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
            let backup = unit.map { givens[$0] }
            for cell in unit {
                givens[cell] = nil
            }
            let newGrade = grader.grade(context: context, givens: givens)
            if let newGrade, newGrade <= target {
                graded = newGrade
            } else {
                for (offset, cell) in unit.enumerated() {
                    givens[cell] = backup[offset]
                }
            }
        }
        return Result(givens: givens, graded: graded)
    }
}
