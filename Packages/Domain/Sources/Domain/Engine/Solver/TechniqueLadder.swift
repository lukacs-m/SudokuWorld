import Model

/// Namespace for the logical technique finders (implemented in the
/// `Techniques+*.swift` files).
enum Techniques {}

/// The ordered catalog of logical techniques, easiest first. The grader and
/// the hint engine both walk this ladder, so a puzzle's difficulty grade
/// always matches the hints it will actually give.
enum TechniqueLadder {
    /// The easiest applicable step at or below the rank cap, or nil when
    /// logic within the cap is stuck. Because the ladder always prefers the
    /// easiest applicable step, capping never changes which steps a full run
    /// would have chosen — it only turns "requires something harder" into an
    /// early stall, which is exactly what capped solvability checks want
    /// (and finders above the cap are never even searched).
    static func nextStep(in grid: SolverGrid, cap: Int = .max) -> SolveStep? {
        if let step = Techniques.nakedSingle(in: grid) {
            return step
        }
        guard cap >= Technique.hiddenSingle.rank else { return nil }
        if let step = Techniques.hiddenSingle(in: grid) {
            return step
        }
        guard cap >= Technique.nakedPair.rank else { return nil }
        if let step = Techniques.nakedSubset(in: grid, subsetSize: 2) {
            return step
        }
        guard cap >= Technique.hiddenPair.rank else { return nil }
        if let step = Techniques.hiddenSubset(in: grid, subsetSize: 2) {
            return step
        }
        guard cap >= Technique.cageArithmetic.rank else { return nil }
        if let step = Techniques.cageArithmetic(in: grid) {
            return step
        }
        // Locked candidates yields pointing (5) or box-line (6); the grade
        // bands never split that pair, so one gate covers both.
        guard cap >= Technique.pointingPair.rank else { return nil }
        if let step = Techniques.lockedCandidates(in: grid) {
            return step
        }
        guard cap >= Technique.nakedTriple.rank else { return nil }
        if let step = Techniques.nakedSubset(in: grid, subsetSize: 3) {
            return step
        }
        guard cap >= Technique.hiddenTriple.rank else { return nil }
        if let step = Techniques.hiddenSubset(in: grid, subsetSize: 3) {
            return step
        }
        guard cap >= Technique.xWing.rank else { return nil }
        if let step = Techniques.xWing(in: grid) {
            return step
        }
        return nil
    }
}

extension Techniques {
    /// All k-element combinations of `elements`, in stable order.
    static func combinations<Element>(of elements: [Element], choose k: Int) -> [[Element]] {
        guard k > 0, elements.count >= k else { return [] }
        if k == elements.count {
            return [elements]
        }
        var result: [[Element]] = []
        var current: [Element] = []

        func extend(from start: Int) {
            if current.count == k {
                result.append(current)
                return
            }
            let needed = k - current.count
            for index in start ... (elements.count - needed) {
                current.append(elements[index])
                extend(from: index + 1)
                current.removeLast()
            }
        }

        extend(from: 0)
        return result
    }
}
