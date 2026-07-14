import Model

/// The non-house constraint families: relation edges (dots, inequalities,
/// thermometers, negative conventions), sum lines (arrows, little killer),
/// and outside clues (sandwich, skyscraper). Each family contributes a
/// place-time check — which is what keeps backtracking and uniqueness
/// counting exact — and a rank-gated fixpoint pass for deduction strength.
extension SolverGrid {
    // MARK: - Relations

    /// Prunes relation partners after an assignment: with one endpoint
    /// fixed, the partner keeps only digits satisfying the edge. This runs
    /// inside `place` (not just the fixpoint passes) so plain backtracking —
    /// filling, uniqueness counting — always honors relation constraints.
    mutating func updateRelations(afterPlacing digit: Int, at cell: Int) -> Bool {
        for edgeIndex in context.relationsForCell[cell] {
            let edge = context.relationEdges[edgeIndex]
            let partner = edge.a == cell ? edge.b : edge.a
            guard values[partner] == 0 else {
                if !edge.satisfied(a: values[edge.a], b: values[edge.b]) {
                    flagContradiction()
                    return false
                }
                continue
            }
            guard pruneRelationPartner(edge: edge, partner: partner, placed: digit) else {
                return false
            }
        }
        return true
    }

    private mutating func pruneRelationPartner(
        edge: RelationEdge,
        partner: Int,
        placed: Int,
    ) -> Bool {
        let allowed = edge.allowedMask(
            forA: edge.a == partner,
            partnerCandidates: SolverContext.mask(for: placed),
            size: context.size,
        )
        let removed = candidates[partner] & ~allowed
        guard removed != 0 else { return true }
        for blocked in context.digits(in: removed) {
            guard eliminate(blocked, at: partner) else { return false }
        }
        return true
    }

    /// Arc consistency over relation edges: each endpoint keeps only digits
    /// with at least one compatible partner candidate.
    mutating func propagateRelations(changed: inout Bool) -> Bool {
        for edge in context.relationEdges {
            for forA in [true, false] {
                let cell = forA ? edge.a : edge.b
                let partner = forA ? edge.b : edge.a
                guard values[cell] == 0 else { continue }
                let partnerMask = values[partner] == 0
                    ? candidates[partner]
                    : SolverContext.mask(for: values[partner])
                let allowed = edge.allowedMask(
                    forA: forA,
                    partnerCandidates: partnerMask,
                    size: context.size,
                )
                let removed = candidates[cell] & ~allowed
                guard removed != 0 else { continue }
                for blocked in context.digits(in: removed) {
                    guard eliminate(blocked, at: cell) else { return false }
                }
                recordPropagationRank(Technique.relationAnalysis.rank)
                changed = true
            }
        }
        return !isContradicted
    }

    // MARK: - Sum lines

    /// Verifies any sum line this assignment completes, and rejects early
    /// when the already-placed shaft exceeds the largest possible target.
    mutating func updateSumLines(afterPlacing _: Int, at cell: Int) -> Bool {
        for lineIndex in context.sumLinesForCell[cell] {
            guard verifySumLine(context.sumLines[lineIndex]) else { return false }
        }
        return true
    }

    private mutating func verifySumLine(_ line: SumLine) -> Bool {
        var placedSum = 0
        var openCells = 0
        for shaftCell in line.cells {
            if values[shaftCell] == 0 {
                openCells += 1
            } else {
                placedSum += values[shaftCell]
            }
        }
        let targetValue: Int? = switch line.target {
        case let .fixed(total): total
        case let .cell(target): values[target] == 0 ? nil : values[target]
        }

        if openCells == 0, let targetValue {
            if placedSum != targetValue {
                flagContradiction()
                return false
            }
            return true
        }
        // Cheap bound: the placed part alone must not exceed the largest
        // reachable target (open shaft cells contribute at least 1 each).
        let maxTarget = switch line.target {
        case let .fixed(total): total

        case let .cell(target): values[target] == 0
            ? maxCandidate(of: target)
            : values[target]
        }
        if placedSum + openCells > maxTarget {
            flagContradiction()
            return false
        }
        return true
    }

    /// Interval propagation over sum lines: the target is boxed into the
    /// shaft's reachable [min, max] sum, and each shaft cell into what the
    /// target leaves after the other cells' extremes.
    mutating func propagateSumLines(changed: inout Bool) -> Bool {
        for line in context.sumLines {
            var shaftMin = 0
            var shaftMax = 0
            for cell in line.cells {
                shaftMin += minCandidate(of: cell)
                shaftMax += maxCandidate(of: cell)
            }
            guard let targetRange = boxTarget(
                of: line,
                shaftMin: shaftMin,
                shaftMax: shaftMax,
                changed: &changed,
            ) else { return false }

            for cell in line.cells where values[cell] == 0 {
                let othersMin = shaftMin - minCandidate(of: cell)
                let othersMax = shaftMax - maxCandidate(of: cell)
                let low = targetRange.lowerBound - othersMax
                let high = targetRange.upperBound - othersMin
                guard low <= high else {
                    flagContradiction()
                    return false
                }
                guard prune(cell: cell, keepingRange: low ... high, changed: &changed) else {
                    return false
                }
            }
        }
        return !isContradicted
    }

    /// The target's possible range after boxing it into the shaft's
    /// reachable sum; nil on contradiction.
    private mutating func boxTarget(
        of line: SumLine,
        shaftMin: Int,
        shaftMax: Int,
        changed: inout Bool,
    ) -> ClosedRange<Int>? {
        switch line.target {
        case let .fixed(total):
            if shaftMin > total || shaftMax < total {
                flagContradiction()
                return nil
            }
            return total ... total

        case let .cell(target):
            if values[target] == 0 {
                guard prune(
                    cell: target,
                    keepingRange: shaftMin ... max(shaftMin, shaftMax),
                    changed: &changed,
                ) else { return nil }
            }
            let low = minCandidate(of: target)
            let high = maxCandidate(of: target)
            return low ... max(low, high)
        }
    }

    // MARK: - Outside clues

    /// Verifies any sandwich/skyscraper line this assignment completes.
    /// Bound propagation for these clues is deliberately partial; this
    /// place-time check is what keeps uniqueness counting exact.
    mutating func updateOutsideClues(afterPlacing _: Int, at cell: Int) -> Bool {
        for lineIndex in context.outsideLinesForCell[cell] {
            let line = context.outsideLines[lineIndex]
            var lineValues: [Int] = []
            lineValues.reserveCapacity(line.cells.count)
            for lineCell in line.cells {
                guard values[lineCell] != 0 else { break }
                lineValues.append(values[lineCell])
            }
            guard lineValues.count == line.cells.count else { continue }
            if !OutsideClues.satisfied(
                clue: line.clue,
                lineValues: lineValues,
                size: context.size,
            ) {
                flagContradiction()
                return false
            }
        }
        return true
    }

    /// Partial deductions from edge clues. Skyscraper: the cell at distance
    /// `d` from the clue can't exceed `size - clue + 1 + d`. Sandwich: a
    /// crust digit (1 or size) can't sit where no partner position yields a
    /// feasible between-sum. Sound but not complete — `updateOutsideClues`
    /// covers exactness at the leaves.
    mutating func propagateOutsideClues(changed: inout Bool) -> Bool {
        for line in context.outsideLines {
            switch line.clue.kind {
            case .skyscraperCount:
                guard skyscraperPrune(
                    clue: line.clue,
                    cells: line.cells,
                    changed: &changed,
                ) else { return false }

            case .sandwichSum:
                guard sandwichPrune(
                    clue: line.clue,
                    cells: line.cells,
                    changed: &changed,
                ) else { return false }

            case .diagonalSum:
                continue // handled as a fixed-target sum line
            }
        }
        return !isContradicted
    }

    private mutating func skyscraperPrune(
        clue: OutsideClue,
        cells: [Int],
        changed: inout Bool,
    ) -> Bool {
        let clueRank = Technique.outsideClueAnalysis.rank
        // Exact specials: clue 1 pins the tallest to the edge; clue `size`
        // forces the whole line ascending.
        if clue.value == 1, values[cells[0]] == 0 {
            guard prune(
                cell: cells[0],
                keepingRange: context.size ... context.size,
                rank: clueRank,
                changed: &changed,
            ) else { return false }
        }
        if clue.value == context.size {
            for (distance, cell) in cells.enumerated() where values[cell] == 0 {
                guard prune(
                    cell: cell,
                    keepingRange: (distance + 1) ... (distance + 1),
                    rank: clueRank,
                    changed: &changed,
                ) else { return false }
            }
        }
        for (distance, cell) in cells.enumerated() where values[cell] == 0 {
            let cap = context.size - clue.value + 1 + distance
            guard cap < context.size else { break }
            guard prune(
                cell: cell,
                keepingRange: 1 ... cap,
                rank: clueRank,
                changed: &changed,
            ) else { return false }
        }
        return true
    }

    /// Eliminates crust digits (1 and size) from positions with no feasible
    /// partner: the cells strictly between the two crusts must be able to
    /// reach the clue with digits from 2...(size-1).
    private mutating func sandwichPrune(
        clue: OutsideClue,
        cells: [Int],
        changed: inout Bool,
    ) -> Bool {
        let size = context.size
        let oneMask = SolverContext.mask(for: 1)
        let topMask = SolverContext.mask(for: size)

        func mayHost(_ mask: DigitMask, at index: Int) -> Bool {
            values[cells[index]] == 0
                ? candidates[cells[index]] & mask != 0
                : SolverContext.mask(for: values[cells[index]]) & mask != 0
        }
        // A sandwich line is a whole row or column — one house — so the
        // interior digits are distinct values from 2...(size-1).
        func feasible(_ a: Int, _ b: Int) -> Bool {
            let betweenCount = abs(a - b) - 1
            guard betweenCount > 0 else { return clue.value == 0 }
            guard betweenCount <= size - 2 else { return false }
            let minSum = betweenCount * (betweenCount + 3) / 2 // 2 + … + (count+1)
            let maxSum = betweenCount * (2 * size - betweenCount - 1) / 2
            return clue.value >= minSum && clue.value <= maxSum
        }

        for (mask, partnerMask) in [(oneMask, topMask), (topMask, oneMask)] {
            for index in cells.indices where mayHost(mask, at: index) {
                let hasPartner = cells.indices.contains { partner in
                    partner != index && mayHost(partnerMask, at: partner)
                        && feasible(index, partner)
                }
                if !hasPartner {
                    guard values[cells[index]] == 0 else {
                        flagContradiction()
                        return false
                    }
                    let crust = mask == oneMask ? 1 : size
                    guard eliminate(crust, at: cells[index]) else { return false }
                    recordPropagationRank(Technique.outsideClueAnalysis.rank)
                    changed = true
                }
            }
        }
        return !isContradicted
    }

    // MARK: - Shared helpers

    func minCandidate(of cell: Int) -> Int {
        values[cell] != 0 ? values[cell] : candidates[cell].trailingZeroBitCount + 1
    }

    func maxCandidate(of cell: Int) -> Int {
        values[cell] != 0
            ? values[cell]
            : DigitMask.bitWidth - candidates[cell].leadingZeroBitCount
    }

    /// Restricts a cell to the digits inside `range`.
    private mutating func prune(
        cell: Int,
        keepingRange range: ClosedRange<Int>,
        rank: Int = Technique.arrowArithmetic.rank,
        changed: inout Bool,
    ) -> Bool {
        let low = max(1, range.lowerBound)
        let high = min(context.size, range.upperBound)
        var keep: DigitMask = 0
        if low <= high {
            for digit in low ... high {
                keep |= SolverContext.mask(for: digit)
            }
        }
        let removed = candidates[cell] & ~keep
        guard removed != 0 else { return true }
        for digit in context.digits(in: removed) {
            guard eliminate(digit, at: cell) else { return false }
        }
        recordPropagationRank(rank)
        changed = true
        return !isContradicted
    }
}
