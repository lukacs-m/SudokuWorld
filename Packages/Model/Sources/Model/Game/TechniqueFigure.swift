/// A hand-built board position illustrating one solving technique for the
/// learning section: the digits and pencil marks on show, the cells the
/// pattern is built from, and the placement or eliminations it yields.
/// Positions are classic 9×9 grids (variant figures add their clue). Cells
/// without declared candidates are unconstrained — the figure leaves them
/// blank. A Domain test replays every figure through the solver ladder to
/// prove the illustrated step is exactly what the engine would find.
public struct TechniqueFigure: Equatable, Sendable {
    public let technique: Technique
    public let variant: SudokuVariant
    /// Fixed digits by cell index.
    public let givens: [Int: Int]
    /// Pencil marks by cell index, for the cells the lesson spells out.
    public let candidates: [Int: [Int]]
    /// Cells the pattern is built from (the pair, the fish corners, …).
    public let focusCells: [Int]
    /// The house(s) the reasoning happens in, shaded more lightly.
    public let regionCells: [Int]
    public let placement: Hint.Placement?
    public let eliminations: [Hint.Elimination]
    public let cages: [Cage]
    public let relations: [RelationClue]
    public let arrows: [Arrow]
    public let outsideClues: [OutsideClue]

    public init(
        technique: Technique,
        variant: SudokuVariant = .classic,
        givens: [Int: Int] = [:],
        candidates: [Int: [Int]] = [:],
        focusCells: [Int],
        regionCells: [Int] = [],
        placement: Hint.Placement? = nil,
        eliminations: [Hint.Elimination] = [],
        cages: [Cage] = [],
        relations: [RelationClue] = [],
        arrows: [Arrow] = [],
        outsideClues: [OutsideClue] = [],
    ) {
        self.technique = technique
        self.variant = variant
        self.givens = givens
        self.candidates = candidates
        self.focusCells = focusCells
        self.regionCells = regionCells
        self.placement = placement
        self.eliminations = eliminations
        self.cages = cages
        self.relations = relations
        self.arrows = arrows
        self.outsideClues = outsideClues
    }

    /// The figure for a technique. Every case has one (pinned by tests).
    public static func figure(for technique: Technique) -> Self {
        all.first { $0.technique == technique } ?? all[0]
    }
}

// MARK: - Grid helpers (9×9, row-major)

private func at(_ row: Int, _ col: Int) -> Int {
    row * 9 + col
}

private func row(_ row: Int) -> [Int] {
    (0 ..< 9).map { at(row, $0) }
}

private func column(_ col: Int) -> [Int] {
    (0 ..< 9).map { at($0, col) }
}

private func box(_ box: Int) -> [Int] {
    let top = (box / 3) * 3
    let left = (box % 3) * 3
    return (0 ..< 9).map { at(top + $0 / 3, left + $0 % 3) }
}

private func eliminate(_ digits: [Int], at cells: [Int]) -> [Hint.Elimination] {
    cells.flatMap { cell in digits.map { Hint.Elimination(index: cell, digit: $0) } }
}

// MARK: - The figures

public extension TechniqueFigure {
    static let all: [TechniqueFigure] = [
        // Row, column, and box together leave a single digit for r5c5.
        TechniqueFigure(
            technique: .nakedSingle,
            givens: [
                at(4, 0): 1, at(4, 1): 2, at(4, 2): 3,
                at(0, 4): 4, at(1, 4): 5,
                at(3, 3): 6, at(3, 5): 7, at(5, 3): 8,
            ],
            focusCells: [at(4, 4)],
            regionCells: row(4) + column(4) + box(4),
            placement: Hint.Placement(index: at(4, 4), digit: 9),
        ),
        // Four 5s outside the centre box block every centre cell but one.
        TechniqueFigure(
            technique: .hiddenSingle,
            givens: [at(3, 0): 5, at(5, 7): 5, at(0, 3): 5, at(8, 5): 5],
            focusCells: [at(4, 4)],
            regionCells: box(4),
            placement: Hint.Placement(index: at(4, 4), digit: 5),
        ),
        // r3c1 and r3c2 are both {4,7}; 4 and 7 leave the rest of row 3.
        TechniqueFigure(
            technique: .nakedPair,
            givens: [at(2, 2): 1, at(2, 3): 2, at(2, 5): 5, at(2, 6): 6, at(2, 8): 9],
            candidates: [
                at(2, 0): [4, 7], at(2, 1): [4, 7],
                at(2, 4): [3, 4, 7, 8], at(2, 7): [3, 4, 7, 8],
            ],
            focusCells: [at(2, 0), at(2, 1)],
            regionCells: row(2),
            eliminations: eliminate([4, 7], at: [at(2, 4), at(2, 7)]),
        ),
        // 2 and 9 only fit in r7c4 and r7c5, so those cells hold nothing else.
        TechniqueFigure(
            technique: .hiddenPair,
            givens: [at(6, 0): 3, at(6, 1): 4, at(6, 5): 6, at(6, 6): 7],
            candidates: [
                at(6, 2): [1, 5, 8],
                at(6, 3): [1, 2, 5, 9], at(6, 4): [2, 5, 8, 9],
                at(6, 7): [1, 5, 8], at(6, 8): [1, 5, 8],
            ],
            focusCells: [at(6, 3), at(6, 4)],
            regionCells: row(6),
            eliminations: [
                Hint.Elimination(index: at(6, 3), digit: 1),
                Hint.Elimination(index: at(6, 3), digit: 5),
                Hint.Elimination(index: at(6, 4), digit: 5),
                Hint.Elimination(index: at(6, 4), digit: 8),
            ],
        ),
        // In box 1, digit 1 only fits on row 1 → it leaves row 1 elsewhere.
        TechniqueFigure(
            technique: .pointingPair,
            givens: [
                at(1, 0): 2, at(1, 1): 3, at(1, 2): 4, at(2, 0): 5, at(2, 1): 6,
                at(5, 2): 1,
                at(0, 4): 2, at(0, 5): 3, at(0, 6): 4, at(0, 7): 5, at(0, 8): 6,
            ],
            candidates: [
                at(0, 0): [1, 7, 8, 9], at(0, 1): [1, 7, 8, 9], at(0, 2): [7, 8, 9],
                at(2, 2): [7, 8, 9], at(0, 3): [1, 7, 8, 9],
            ],
            focusCells: [at(0, 0), at(0, 1)],
            regionCells: box(0) + row(0),
            eliminations: eliminate([1], at: [at(0, 3)]),
        ),
        // In row 4, digit 6 only fits inside box 4 → it leaves the box elsewhere.
        TechniqueFigure(
            technique: .boxLineReduction,
            givens: [
                at(3, 2): 1, at(3, 3): 2, at(3, 5): 3, at(3, 6): 4, at(3, 8): 5,
                at(7, 4): 6, at(1, 7): 6,
                at(4, 0): 7, at(4, 1): 2, at(5, 0): 3, at(5, 2): 4,
            ],
            candidates: [
                at(3, 0): [6, 8, 9], at(3, 1): [6, 8, 9],
                at(3, 4): [7, 8, 9], at(3, 7): [7, 8, 9],
            ],
            focusCells: [at(3, 0), at(3, 1)],
            regionCells: row(3) + box(3),
            eliminations: eliminate([6], at: [at(4, 2), at(5, 1)]),
        ),
        // {1,2}, {2,3}, {1,3} lock 1, 2, 3 into three cells of row 1.
        TechniqueFigure(
            technique: .nakedTriple,
            givens: [at(0, 4): 4, at(0, 5): 5, at(0, 8): 6],
            candidates: [
                at(0, 0): [1, 2], at(0, 1): [2, 3], at(0, 2): [1, 3],
                at(0, 3): [1, 3, 7, 8, 9], at(0, 6): [1, 8, 9], at(0, 7): [2, 7, 9],
            ],
            focusCells: [at(0, 0), at(0, 1), at(0, 2)],
            regionCells: row(0),
            eliminations: [
                Hint.Elimination(index: at(0, 3), digit: 1),
                Hint.Elimination(index: at(0, 3), digit: 3),
                Hint.Elimination(index: at(0, 6), digit: 1),
                Hint.Elimination(index: at(0, 7), digit: 2),
            ],
        ),
        // The 1s, 2s and 3s in boxes 2 and 3 push all three digits into the
        // first three cells of row 1, which then hold nothing else.
        TechniqueFigure(
            technique: .hiddenTriple,
            givens: [
                at(0, 3): 4, at(0, 4): 5,
                at(1, 3): 1, at(1, 4): 2, at(2, 5): 3,
                at(2, 6): 1, at(2, 7): 2, at(1, 8): 3,
            ],
            candidates: [
                at(0, 0): [1, 2, 6, 7], at(0, 1): [2, 3, 7, 8], at(0, 2): [1, 3, 8, 9],
                at(0, 5): [6, 7, 8, 9], at(0, 6): [6, 7, 8, 9],
                at(0, 7): [6, 7, 8, 9], at(0, 8): [6, 7, 8, 9],
            ],
            focusCells: [at(0, 0), at(0, 1), at(0, 2)],
            regionCells: row(0),
            eliminations: [
                Hint.Elimination(index: at(0, 0), digit: 6),
                Hint.Elimination(index: at(0, 0), digit: 7),
                Hint.Elimination(index: at(0, 1), digit: 7),
                Hint.Elimination(index: at(0, 1), digit: 8),
                Hint.Elimination(index: at(0, 2), digit: 8),
                Hint.Elimination(index: at(0, 2), digit: 9),
            ],
        ),
        // Digit 4 sits in columns 3 and 7 on both rows 2 and 8 → the four
        // corners cover the digit, so it leaves the rest of those columns.
        TechniqueFigure(
            technique: .xWing,
            givens: [
                at(1, 0): 1, at(1, 1): 2, at(1, 3): 3, at(1, 5): 6, at(1, 7): 7, at(1, 8): 8,
                at(7, 0): 5, at(7, 1): 7, at(7, 3): 6, at(7, 5): 8, at(7, 7): 1, at(7, 8): 2,
                at(5, 4): 4,
                at(0, 2): 7, at(2, 2): 8, at(3, 2): 1, at(5, 2): 2, at(8, 2): 3,
                at(0, 6): 1, at(2, 6): 2, at(3, 6): 7, at(5, 6): 6, at(8, 6): 5,
            ],
            candidates: [
                at(1, 2): [4, 5, 9], at(1, 4): [5, 9], at(1, 6): [4, 9],
                at(7, 2): [4, 9], at(7, 4): [3, 9], at(7, 6): [3, 4, 9],
            ],
            focusCells: [at(1, 2), at(1, 6), at(7, 2), at(7, 6)],
            regionCells: row(1) + row(7),
            eliminations: eliminate([4], at: [at(4, 2), at(6, 2), at(4, 6), at(6, 6)]),
        ),
        // Digit 3 on rows 2, 5 and 8 stays inside columns 2, 5 and 8 → it
        // leaves those columns everywhere else.
        TechniqueFigure(
            technique: .swordfish,
            givens: [
                at(1, 0): 1, at(1, 2): 2, at(1, 3): 6, at(1, 5): 4, at(1, 7): 7, at(1, 8): 8,
                at(4, 0): 9, at(4, 1): 1, at(4, 3): 7, at(4, 5): 5, at(4, 6): 2, at(4, 8): 4,
                at(7, 0): 6, at(7, 2): 1, at(7, 4): 2, at(7, 5): 8, at(7, 6): 7, at(7, 8): 9,
                at(3, 2): 3, at(0, 6): 3, at(6, 3): 3,
                at(5, 1): 2, at(2, 4): 5, at(8, 7): 1,
            ],
            candidates: [
                at(1, 1): [3, 5, 9], at(1, 4): [3, 9], at(1, 6): [5, 9],
                at(4, 2): [6, 8], at(4, 4): [3, 6, 8], at(4, 7): [3, 6, 8],
                at(7, 1): [3, 4, 5], at(7, 3): [4, 5], at(7, 7): [3, 4, 5],
            ],
            focusCells: [at(1, 1), at(1, 4), at(4, 4), at(4, 7), at(7, 1), at(7, 7)],
            regionCells: row(1) + row(4) + row(7),
            eliminations: eliminate([3], at: [at(2, 1), at(8, 1), at(5, 4), at(5, 7)]),
        ),
        // Pivot {1,2} with pincers {1,3} and {2,3}: one pincer is 3 either way.
        TechniqueFigure(
            technique: .xyWing,
            candidates: [
                at(4, 4): [1, 2], at(4, 7): [1, 3], at(7, 4): [2, 3],
                at(7, 7): [3, 5, 8],
            ],
            focusCells: [at(4, 4), at(4, 7), at(7, 4)],
            eliminations: [Hint.Elimination(index: at(7, 7), digit: 3)],
        ),
        // {1,2}→{2,3}→{3,4}→{4,1}: one end of the chain is 1 whatever happens.
        TechniqueFigure(
            technique: .xyChain,
            candidates: [
                at(0, 0): [1, 2], at(0, 4): [2, 3], at(3, 4): [3, 4], at(3, 8): [1, 4],
                at(0, 8): [1, 5, 7], at(3, 0): [1, 6, 9],
            ],
            focusCells: [at(0, 0), at(0, 4), at(3, 4), at(3, 8)],
            eliminations: eliminate([1], at: [at(0, 8), at(3, 0)]),
        ),
        // Three cells summing to 7 can only be 1+2+4; with the 1 placed the two
        // open cells must make 6 out of distinct digits, so 3 drops out. The
        // anchor cell is a given so no pencil mark sits under the sum label.
        TechniqueFigure(
            technique: .cageArithmetic,
            variant: .killer,
            givens: [at(3, 3): 1],
            candidates: [at(3, 4): [2, 3, 4], at(4, 3): [2, 3, 4]],
            focusCells: [at(3, 3), at(3, 4), at(4, 3)],
            eliminations: eliminate([3], at: [at(3, 4), at(4, 3)]),
            cages: [Cage(cells: [at(3, 3), at(3, 4), at(4, 3)], sum: 7)],
        ),
        // A black dot needs a double/half partner: 5, 7 and 9 have none.
        TechniqueFigure(
            technique: .relationAnalysis,
            variant: .kropki,
            candidates: [at(4, 3): [3, 5, 7, 9]],
            focusCells: [at(4, 3), at(4, 4)],
            eliminations: eliminate([5, 7, 9], at: [at(4, 3)]),
            relations: [RelationClue(a: at(4, 3), b: at(4, 4), kind: .blackDot)],
        ),
        // The shaft already holds a 4 and its other cell is at least 1, so
        // the circle is at least 5.
        TechniqueFigure(
            technique: .arrowArithmetic,
            variant: .arrow,
            givens: [at(4, 5): 4],
            candidates: [at(4, 4): [2, 3, 5, 6, 7, 8]],
            focusCells: [at(4, 4), at(4, 5), at(4, 6)],
            eliminations: eliminate([2, 3], at: [at(4, 4)]),
            arrows: [Arrow(circle: at(4, 4), shaft: [at(4, 5), at(4, 6)])],
        ),
        // A skyscraper clue of 3 needs two taller buildings behind the
        // first, so the edge cell is at most 7.
        TechniqueFigure(
            technique: .outsideClueAnalysis,
            variant: .skyscraper,
            candidates: [at(4, 0): Array(1 ... 9)],
            focusCells: row(4),
            regionCells: row(4),
            eliminations: eliminate([8, 9], at: [at(4, 0)]),
            outsideClues: [
                OutsideClue(kind: .skyscraperCount, side: .leading, offset: 4, value: 3),
            ],
        ),
    ]
}
