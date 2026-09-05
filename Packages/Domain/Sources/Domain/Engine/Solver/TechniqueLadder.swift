import Model

/// Namespace for the logical technique finders (implemented in the
/// `Techniques+*.swift` files).
enum Techniques {}

/// The ordered catalog of logical techniques, easiest first. The grader and
/// the hint engine both walk this ladder, so a puzzle's difficulty grade
/// always matches the hints it will actually give.
enum TechniqueLadder {
    /// One rung: the gate rank a capped search must clear, and the finder.
    private struct Rung: Sendable {
        let gate: Int
        let finder: @Sendable (SolverGrid) -> SolveStep?
    }

    /// Easiest first. Locked candidates yields pointing (5) or box-line (6);
    /// the grade bands never split that pair, so one gate covers both. The
    /// bent-line lock is pointing over a fold, so it rides at the same gate.
    private static let rungs: [Rung] = [
        Rung(gate: Technique.nakedSingle.rank) { Techniques.nakedSingle(in: $0) },
        Rung(gate: Technique.hiddenSingle.rank) { Techniques.hiddenSingle(in: $0) },
        Rung(gate: Technique.relationAnalysis.rank) { Techniques.relationAnalysis(in: $0) },
        Rung(gate: Technique.nakedPair.rank) { Techniques.nakedSubset(in: $0, subsetSize: 2) },
        Rung(gate: Technique.hiddenPair.rank) { Techniques.hiddenSubset(in: $0, subsetSize: 2) },
        Rung(gate: Technique.cageArithmetic.rank) { Techniques.cageArithmetic(in: $0) },
        Rung(gate: Technique.arrowArithmetic.rank) { Techniques.arrowArithmetic(in: $0) },
        Rung(gate: Technique.pointingPair.rank) { Techniques.lockedCandidates(in: $0) },
        Rung(gate: Technique.bentLine.rank) { Techniques.bentLineLock(in: $0) },
        Rung(gate: Technique.nakedTriple.rank) { Techniques.nakedSubset(in: $0, subsetSize: 3) },
        Rung(gate: Technique.hiddenTriple.rank) { Techniques.hiddenSubset(in: $0, subsetSize: 3) },
        Rung(gate: Technique.xWing.rank) { Techniques.xWing(in: $0) },
        Rung(gate: Technique.outsideClueAnalysis.rank) { Techniques.outsideClueAnalysis(in: $0) },
        Rung(gate: Technique.swordfish.rank) { Techniques.swordfish(in: $0) },
        Rung(gate: Technique.xyWing.rank) { Techniques.xyWing(in: $0) },
        Rung(gate: Technique.xyChain.rank) { Techniques.xyChain(in: $0) },
    ]

    /// The easiest applicable step at or below the rank cap, or nil when
    /// logic within the cap is stuck. Because the ladder always prefers the
    /// easiest applicable step, capping never changes which steps a full run
    /// would have chosen — it only turns "requires something harder" into an
    /// early stall, which is exactly what capped solvability checks want
    /// (and finders above the cap are never even searched).
    static func nextStep(in grid: SolverGrid, cap: Int = .max) -> SolveStep? {
        for rung in rungs {
            guard cap >= rung.gate else { return nil }
            if let step = rung.finder(grid) {
                return step
            }
        }
        return nil
    }
}

extension Techniques {
    /// All `size`-element combinations of `elements`, in stable order.
    static func combinations<Element>(of elements: [Element], choose size: Int) -> [[Element]] {
        guard size > 0, elements.count >= size else { return [] }
        if size == elements.count {
            return [elements]
        }
        var result: [[Element]] = []
        var current: [Element] = []

        func extend(from start: Int) {
            if current.count == size {
                result.append(current)
                return
            }
            let needed = size - current.count
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
