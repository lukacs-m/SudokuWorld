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
    struct Request {
        let context: SolverContext
        let solution: [Int]
        let target: Difficulty
        let minimumGivens: Int
        let hardeningFloor: Int
        let symmetric: Bool
    }

    struct Result {
        var givens: [Int?]
        /// The grade after carving; nil never escapes (a full board grades
        /// beginner, and only solvable states are kept).
        var graded: Difficulty?
    }

    static func carve(
        _ request: Request,
        grader: Grader,
        rng: inout Xoshiro256StarStar,
    ) -> Result {
        var digger = Digger(request: request, grader: grader)
        digger.units = removalUnits(
            context: request.context,
            symmetric: request.symmetric,
            rng: &rng,
        )

        // Stage 1: respect the density floor.
        digger.dig(floor: request.minimumGivens, probeGrade: false)
        var graded = grader.grade(context: request.context, givens: digger.givens)

        // Stage 2: harden past the floor when the grade came up short.
        // Beginner/easy floor states are their target by construction (or a
        // hair below, which is fine at that tier); mid and upper tiers need
        // boards that *require* their techniques. The hardening floor keeps
        // the tiers' density ladder intact (a hard board must not carve down
        // to master sparseness). Restricted to 9×9-class grids: on
        // samurai-size boards the per-probe grade is too expensive and the
        // density floor matters more than label exactness.
        if request.target >= .medium, request.context.cellCount <= 200,
           request.hardeningFloor < request.minimumGivens,
           let current = graded, current < request.target
        {
            // A fresh pass over everything still given — stage 1 consumed its
            // unit list, including cells its floor guard merely skipped.
            digger.units = (0 ..< request.context.cellCount)
                .filter { digger.givens[$0] != nil }
                .shuffled(using: &rng)
                .map { [$0] }
            digger.index = 0
            digger.consecutiveRejections = 0

            // Master wants maximum depth regardless — skip the per-batch
            // probes and grade once at the end.
            digger.dig(
                floor: request.hardeningFloor,
                probeGrade: request.target != .master,
            )
            graded = grader.grade(context: request.context, givens: digger.givens)
        }
        return Result(givens: digger.givens, graded: graded)
    }

    /// The mutable digging state one carve walks through.
    private struct Digger {
        let request: Request
        let grader: Grader
        let rejectionLimit: Int
        let batchSize: Int
        var givens: [Int?]
        var givensCount: Int
        var consecutiveRejections = 0
        var index = 0
        var units: [[Int]] = []

        init(request: Request, grader: Grader) {
            self.request = request
            self.grader = grader
            rejectionLimit = GivensCarver.rejectionLimit(cellCount: request.context.cellCount)
            batchSize = GivensCarver.batchUnits(cellCount: request.context.cellCount)
            givens = request.solution
            givensCount = request.context.cellCount
        }

        /// Digs from the current cursor down to `floor`. With `probeGrade`,
        /// the full grade runs after every round that removed something, and
        /// digging stops as soon as the target grade is reached.
        mutating func dig(floor: Int, probeGrade: Bool) {
            while index < units.count {
                if givensCount <= floor || consecutiveRejections >= rejectionLimit {
                    break
                }

                let end = min(index + batchSize, units.count)
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
                    accepted = digUnits(batch, floor: floor)
                }
                index = end

                if probeGrade, accepted,
                   grader.grade(context: request.context, givens: givens) == request.target
                {
                    return
                }
            }
        }

        /// The batch failed or didn't fit: retry its units one by one.
        private mutating func digUnits(_ batch: [[Int]], floor: Int) -> Bool {
            var accepted = false
            for unit in batch {
                if givensCount <= floor || consecutiveRejections >= rejectionLimit {
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
            return accepted
        }

        /// Attempts to remove `cells` as one step at the target's acceptance
        /// cap; restores them on failure.
        private mutating func tryRemove(_ cells: [Int]) -> Bool {
            let backup = cells.map { givens[$0] }
            for cell in cells {
                givens[cell] = nil
            }
            if grader.solvesWithin(
                target: request.target,
                context: request.context,
                givens: givens,
            ) {
                givensCount -= cells.count
                return true
            }
            for (offset, cell) in cells.enumerated() {
                givens[cell] = backup[offset]
            }
            return false
        }
    }

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
