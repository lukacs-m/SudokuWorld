import Model

/// Digs givens out of a full solution in two stages per difficulty:
///
/// - **Stage 1 — to the floor.** Removals are kept while the puzzle stays
///   solvable within the target's technique cap (capped-solvable implies a
///   unique solution — every deduction is forced), stopping at the
///   difficulty's givens floor so boards keep their tier's density.
/// - **Stage 2 — hardening (medium and up).** If the floor state grades
///   below the target (a 28-given board rarely *requires* hard techniques),
///   digging continues past the floor, probing the grade after each accepted
///   batch, until the target grade is reached or removals run out. This is
///   what makes requested and delivered difficulty actually agree — without
///   it the generator wastes its whole retry budget hunting grades the floor
///   makes unreachable.
///
/// The work is deterministically bounded: removals run in speculative
/// batches (one solvability check per chunk, per-unit retry on failure) and
/// digging stops after a run of consecutive failed removals. Works in
/// 180°-symmetric pairs when asked.
enum GivensCarver {
    /// Units speculatively removed per batch check. Large grids batch more
    /// aggressively — their per-check solves are the expensive part.
    private static func batchUnits(cellCount: Int) -> Int {
        cellCount > 200 ? 8 : 4
    }

    /// Stop digging after this many failed unit removals in a row: near
    /// minimal, further attempts almost never succeed and each one costs a
    /// full solve. Large grids get a tight limit (their solves are ~5× the
    /// cost); 9×9-class grids get enough persistence for deep master digs.
    private static func rejectionLimit(cellCount: Int) -> Int {
        cellCount > 200 ? 10 : 30
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
        hardeningFloor: Int,
        symmetric: Bool,
        rng: inout Xoshiro256StarStar,
        grader: Grader,
    ) -> Result {
        var givens: [Int?] = solution
        var givensCount = context.cellCount
        var consecutiveRejections = 0
        var index = 0
        let rejectionLimit = Self.rejectionLimit(cellCount: context.cellCount)
        let batchUnits = Self.batchUnits(cellCount: context.cellCount)
        var units = removalUnits(context: context, symmetric: symmetric, rng: &rng)

        /// Attempts to remove `cells` as one step; restores them on failure.
        func tryRemove(_ cells: [Int]) -> Bool {
            let backup = cells.map { givens[$0] }
            for cell in cells {
                givens[cell] = nil
            }
            if grader.solvesWithin(target: target, context: context, givens: givens) {
                givensCount -= cells.count
                return true
            }
            for (offset, cell) in cells.enumerated() {
                givens[cell] = backup[offset]
            }
            return false
        }

        /// Digs from the current cursor down to `floor`. With `probeGrade`,
        /// the full grade runs after every round that removed something, and
        /// digging stops as soon as the target grade is reached.
        func dig(floor: Int, probeGrade: Bool) {
            while index < units.count {
                if givensCount <= floor {
                    break
                }
                if consecutiveRejections >= rejectionLimit {
                    break
                }

                let end = min(index + batchUnits, units.count)
                let batch = Array(units[index ..< end])
                let batchCells = batch.flatMap(\.self)
                var accepted = false

                // Speculative batch: one solvability check for several units.
                if batch.count > 1,
                   givensCount - batchCells.count >= floor,
                   tryRemove(batchCells)
                {
                    consecutiveRejections = 0
                    accepted = true
                } else {
                    // Batch failed or didn't fit: retry its units one by one.
                    for unit in batch {
                        if givensCount <= floor {
                            break
                        }
                        if consecutiveRejections >= rejectionLimit {
                            break
                        }
                        // A pair may overshoot the floor where a single fits.
                        if givensCount - unit.count < floor {
                            continue
                        }

                        if tryRemove(unit) {
                            consecutiveRejections = 0
                            accepted = true
                        } else {
                            consecutiveRejections += 1
                        }
                    }
                }
                index = end

                if probeGrade, accepted,
                   grader.grade(context: context, givens: givens) == target
                {
                    return
                }
            }
        }

        // Stage 1: respect the density floor.
        dig(floor: minimumGivens, probeGrade: false)
        var graded = grader.grade(context: context, givens: givens)

        // Stage 2: harden past the floor when the grade came up short.
        // Beginner/easy floor states are their target by construction (or a
        // hair below, which is fine at that tier); mid and upper tiers need
        // boards that *require* their techniques. The hardening floor keeps
        // the tiers' density ladder intact (a hard board must not carve down
        // to master sparseness). Restricted to 9×9-class grids: on
        // samurai-size boards the per-probe grade is too expensive and the
        // density floor matters more than label exactness.
        if target >= .medium, context.cellCount <= 200,
           hardeningFloor < minimumGivens, // else stage 1 already dug this deep
           let current = graded, current < target
        {
            // A fresh pass over everything still given — stage 1 consumed its
            // unit list, including cells its floor guard merely skipped.
            units = (0 ..< context.cellCount)
                .filter { givens[$0] != nil }
                .shuffled(using: &rng)
                .map { [$0] }
            index = 0
            consecutiveRejections = 0
            // Master wants maximum depth regardless — skip the per-batch
            // probes and grade once at the end.
            dig(floor: hardeningFloor, probeGrade: target != .master)
            graded = grader.grade(context: context, givens: givens)
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
