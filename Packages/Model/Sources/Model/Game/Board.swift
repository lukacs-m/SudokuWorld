/// A live board: the mutable state layered over a puzzle's givens.
/// Pure data — all game rules (mistakes, conflicts, undo) live in Domain.
public struct Board: Equatable, Sendable, Codable {
    public private(set) var cells: [BoardCell]

    /// A fresh board with the puzzle's givens locked in.
    public init(puzzle: PuzzleDefinition) {
        cells = puzzle.givens.map { value in
            BoardCell(value: value, isGiven: value != nil)
        }
    }

    public init(cells: [BoardCell]) {
        self.cells = cells
    }

    public var count: Int {
        cells.count
    }

    public subscript(index: Int) -> BoardCell {
        get { cells[index] }
        set { cells[index] = newValue }
    }

    public var filledCount: Int {
        cells.count { $0.value != nil }
    }

    public var isFilled: Bool {
        cells.allSatisfy { $0.value != nil }
    }

    /// Current values by cell index (nil where empty).
    public var values: [Int?] {
        cells.map(\.value)
    }
}
