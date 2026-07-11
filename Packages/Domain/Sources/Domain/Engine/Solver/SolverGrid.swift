import Model

/// Mutable solving state: values, candidate bitmasks, and killer-cage
/// arithmetic, kept consistent through incremental constraint propagation.
/// A value type so backtracking can branch by copying.
struct SolverGrid {
    let context: SolverContext
    /// 0 = unsolved.
    private(set) var values: [Int]
    /// Candidate digits per cell; 0 for solved cells.
    private(set) var candidates: [UInt16]
    private(set) var unsolvedCount: Int
    private(set) var isContradicted: Bool
    /// Hardest technique rank exercised by `propagate()` so far (-1 = none):
    /// naked single 0, hidden single 1, cage arithmetic 4. Lets the grader
    /// use bulk propagation without losing difficulty attribution.
    private(set) var propagationHardestRank: Int = -1
    /// Digits already placed in each house, maintained incrementally by
    /// `place` — the finders consult this constantly, and recomputing it by
    /// scanning house cells dominated solve time.
    private var housePlaced: [UInt16]

    private var cageRemainingSum: [Int]
    private var cageRemainingCount: [Int]
    private var cageUsedMask: [UInt16]

    init(context: SolverContext, givens: [Int?]) {
        self.context = context
        values = [Int](repeating: 0, count: context.cellCount)
        unsolvedCount = context.cellCount
        isContradicted = false
        housePlaced = [UInt16](repeating: 0, count: context.houses.count)

        var initial = [UInt16](repeating: context.fullMask, count: context.cellCount)
        for (cell, parity) in context.parities {
            var mask: UInt16 = 0
            for digit in 1 ... context.size where parity.accepts(digit) {
                mask |= SolverContext.mask(for: digit)
            }
            initial[cell] = mask
        }
        candidates = initial

        cageRemainingSum = context.cages.map(\.sum)
        cageRemainingCount = context.cages.map(\.cells.count)
        cageUsedMask = [UInt16](repeating: 0, count: context.cages.count)

        for (cell, given) in givens.enumerated() {
            guard let given else { continue }
            guard place(given, at: cell) else { return }
        }
    }

    var isSolved: Bool {
        unsolvedCount == 0 && !isContradicted
    }

    /// Assigns a digit and propagates eliminations to peers and cage state.
    /// Returns false (and flags contradiction) when the assignment is illegal.
    @discardableResult
    mutating func place(_ digit: Int, at cell: Int) -> Bool {
        guard !isContradicted else { return false }
        if values[cell] != 0 {
            if values[cell] == digit {
                return true
            }
            isContradicted = true
            return false
        }
        let mask = SolverContext.mask(for: digit)
        guard candidates[cell] & mask != 0 else {
            isContradicted = true
            return false
        }

        values[cell] = digit
        candidates[cell] = 0
        unsolvedCount -= 1
        for house in context.housesForCell[cell] {
            housePlaced[house] |= mask
        }

        for peer in context.peers[cell] {
            guard eliminate(digit, at: peer) else { return false }
        }
        return updateCage(afterPlacing: digit, at: cell)
    }

    /// Removes a candidate. Returns false on contradiction (empty cell).
    @discardableResult
    mutating func eliminate(_ digit: Int, at cell: Int) -> Bool {
        guard !isContradicted else { return false }
        if values[cell] != 0 {
            if values[cell] == digit {
                isContradicted = true
                return false
            }
            return true
        }
        let mask = SolverContext.mask(for: digit)
        guard candidates[cell] & mask != 0 else { return true }
        candidates[cell] &= ~mask
        if candidates[cell] == 0 {
            isContradicted = true
            return false
        }
        return true
    }

    /// Runs all forced deductions to a fixed point: naked singles, hidden
    /// singles, and killer-cage combination pruning. Everything here is
    /// logically forced, so solution counting stays exact while the search
    /// space collapses dramatically (killer grids with no givens would be
    /// near-brute-force otherwise). Returns false on contradiction.
    ///
    /// `maxRank` caps the techniques used (see `Technique.rank`): passes above
    /// the cap are skipped entirely, which is what lets a beginner-capped
    /// solvability check run as a pure naked-single fixpoint.
    @discardableResult
    mutating func propagate(maxRank: Int = .max) -> Bool {
        var changed = true
        while changed, !isContradicted {
            changed = false
            guard propagateNakedSingles(changed: &changed) else { return false }
            if maxRank >= Technique.hiddenSingle.rank {
                guard propagateHiddenSingles(changed: &changed) else { return false }
            }
            if maxRank >= Technique.cageArithmetic.rank {
                guard propagateCageCombinations(changed: &changed) else { return false }
            }
        }
        return !isContradicted
    }

    /// Places every cell whose candidates collapsed to a single digit.
    private mutating func propagateNakedSingles(changed: inout Bool) -> Bool {
        var localChange = true
        while localChange, !isContradicted {
            localChange = false
            for cell in 0 ..< context.cellCount where values[cell] == 0 {
                let mask = candidates[cell]
                if mask == 0 {
                    isContradicted = true
                    return false
                }
                if mask.nonzeroBitCount == 1 {
                    let digit = mask.trailingZeroBitCount + 1
                    guard place(digit, at: cell) else { return false }
                    propagationHardestRank = max(propagationHardestRank, Technique.nakedSingle.rank)
                    localChange = true
                    changed = true
                }
            }
        }
        return !isContradicted
    }

    /// Places digits that have exactly one home left in a house.
    private mutating func propagateHiddenSingles(changed: inout Bool) -> Bool {
        for houseIndex in context.houses.indices {
            let placed = housePlacements(houseIndex)
            for digit in 1 ... context.size {
                let mask = SolverContext.mask(for: digit)
                guard placed & mask == 0 else { continue }

                var home = -1
                var count = 0
                for cell in context.houses[houseIndex]
                    where values[cell] == 0 && candidates[cell] & mask != 0
                {
                    home = cell
                    count += 1
                    if count > 1 {
                        break
                    }
                }
                if count == 0 {
                    isContradicted = true
                    return false
                }
                if count == 1 {
                    guard place(digit, at: home) else { return false }
                    propagationHardestRank = max(
                        propagationHardestRank,
                        Technique.hiddenSingle.rank,
                    )
                    changed = true
                }
            }
        }
        return !isContradicted
    }

    /// Strips cage-cell candidates that appear in no digit combination
    /// matching the cage's remaining sum and count.
    private mutating func propagateCageCombinations(changed: inout Bool) -> Bool {
        for (index, cage) in context.cages.enumerated() {
            let remaining = cageRemainingCount[index]
            guard remaining > 0 else { continue }

            let available = context.fullMask & ~cageUsedMask[index]
            let usable = CageCombinations.usableDigits(
                count: remaining,
                sum: cageRemainingSum[index],
                available: available,
                size: context.size,
            )
            if usable == 0 {
                isContradicted = true
                return false
            }
            for cell in cage.cells where values[cell] == 0 {
                let extras = candidates[cell] & ~usable
                guard extras != 0 else { continue }
                for digit in context.digits(in: extras) {
                    guard eliminate(digit, at: cell) else { return false }
                    propagationHardestRank = max(
                        propagationHardestRank,
                        Technique.cageArithmetic.rank,
                    )
                    changed = true
                }
            }
        }
        return !isContradicted
    }

    /// The unsolved cell with the fewest candidates (minimum remaining values).
    func minimumRemainingCell() -> Int? {
        var best: Int?
        var bestCount = Int.max
        for cell in 0 ..< context.cellCount where values[cell] == 0 {
            let count = candidates[cell].nonzeroBitCount
            if count < bestCount {
                best = cell
                bestCount = count
                if count <= 2 {
                    break
                }
            }
        }
        return best
    }

    /// Digits already placed in a house (cached, updated on placement).
    func housePlacements(_ houseIndex: Int) -> UInt16 {
        housePlaced[houseIndex]
    }

    // MARK: - Killer cages

    struct CageState {
        let remainingSum: Int
        let remainingCount: Int
        let usedMask: UInt16
    }

    func cageState(_ index: Int) -> CageState {
        CageState(
            remainingSum: cageRemainingSum[index],
            remainingCount: cageRemainingCount[index],
            usedMask: cageUsedMask[index],
        )
    }

    private mutating func updateCage(afterPlacing digit: Int, at cell: Int) -> Bool {
        let cage = context.cageIndexForCell[cell]
        guard cage >= 0 else { return true }

        let mask = SolverContext.mask(for: digit)
        if cageUsedMask[cage] & mask != 0 {
            isContradicted = true
            return false
        }
        cageUsedMask[cage] |= mask
        cageRemainingSum[cage] -= digit
        cageRemainingCount[cage] -= 1

        let remaining = cageRemainingCount[cage]
        let target = cageRemainingSum[cage]
        if remaining == 0 {
            if target != 0 {
                isContradicted = true
                return false
            }
            return true
        }
        let available = context.fullMask & ~cageUsedMask[cage]
        let bounds = CageCombinations.sumBounds(
            count: remaining,
            available: available,
            size: context.size,
        )
        if target < bounds.min || target > bounds.max {
            isContradicted = true
            return false
        }
        return true
    }
}
