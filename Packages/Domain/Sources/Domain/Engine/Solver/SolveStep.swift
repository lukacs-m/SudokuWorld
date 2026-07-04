import Model

/// One application of a logical technique: what to place, what to eliminate,
/// and what to spotlight when explaining the step.
struct SolveStep {
    let technique: Technique
    let placements: [(cell: Int, digit: Int)]
    let eliminations: [(cell: Int, digit: Int)]
    /// Cells the step's reasoning hinges on (the pair, the wing corners, …).
    let focusCells: [Int]
    /// Digits the step's reasoning is about.
    let focusDigits: [Int]

    init(
        technique: Technique,
        placements: [(cell: Int, digit: Int)] = [],
        eliminations: [(cell: Int, digit: Int)] = [],
        focusCells: [Int],
        focusDigits: [Int],
    ) {
        self.technique = technique
        self.placements = placements
        self.eliminations = eliminations
        self.focusCells = focusCells
        self.focusDigits = focusDigits
    }

    /// Applies the step to a grid. Returns false on contradiction.
    @discardableResult
    func apply(to grid: inout SolverGrid) -> Bool {
        for (cell, digit) in eliminations {
            guard grid.eliminate(digit, at: cell) else { return false }
        }
        for (cell, digit) in placements {
            guard grid.place(digit, at: cell) else { return false }
        }
        return true
    }
}
