import Model

/// Namespace for the logical technique finders (implemented in the
/// `Techniques+*.swift` files).
enum Techniques {}

/// The ordered catalog of logical techniques, easiest first. The grader and
/// the hint engine both walk this ladder, so a puzzle's difficulty grade
/// always matches the hints it will actually give.
enum TechniqueLadder {
    /// The easiest applicable step, or nil when logic alone is stuck.
    static func nextStep(in grid: SolverGrid) -> SolveStep? {
        if let step = Techniques.nakedSingle(in: grid) { return step }
        if let step = Techniques.hiddenSingle(in: grid) { return step }
        if let step = Techniques.nakedSubset(in: grid, subsetSize: 2) { return step }
        if let step = Techniques.hiddenSubset(in: grid, subsetSize: 2) { return step }
        if let step = Techniques.cageArithmetic(in: grid) { return step }
        if let step = Techniques.lockedCandidates(in: grid) { return step }
        if let step = Techniques.nakedSubset(in: grid, subsetSize: 3) { return step }
        if let step = Techniques.hiddenSubset(in: grid, subsetSize: 3) { return step }
        if let step = Techniques.xWing(in: grid) { return step }
        return nil
    }
}

extension Techniques {
    /// All k-element combinations of `elements`, in stable order.
    static func combinations<Element>(of elements: [Element], choose k: Int) -> [[Element]] {
        guard k > 0, elements.count >= k else { return [] }
        if k == elements.count { return [elements] }
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
