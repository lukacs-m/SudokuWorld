/// The structural shape of a variant's grid: which cells exist, and which
/// groups of cells must each contain every digit exactly once ("houses").
///
/// One topology serves the whole engine — the solver, generator, grader, and
/// board renderer all consume the same data, so adding a variant never touches
/// the core algorithms. Per-puzzle constraints (killer cages, parity marks)
/// live on `PuzzleDefinition`, not here.
public struct GridTopology: Equatable, Sendable, Codable {
    public let variant: SudokuVariant
    /// Digits run 1...size.
    public let size: Int
    /// Bounding box; positions not listed in `cells` are inactive (the empty
    /// corners of a samurai layout).
    public let rowCount: Int
    public let colCount: Int
    /// Active cells. A cell's index in this array is its identity everywhere:
    /// givens, solutions, boards, houses, cages, and hints all use it.
    public let cells: [GridPosition]
    /// All-different units: rows, columns, boxes, plus variant extras.
    public let houses: [[Int]]
    /// The kind of each house, parallel to `houses`.
    public let houseKinds: [HouseKind]
    /// Box id per cell, for rendering box borders and alternating shading.
    public let boxIndex: [Int]
    /// Windoku's four shaded windows (also present in `houses`).
    public let windows: [[Int]]
    /// Marked diagonal lines of X-Sudoku and argyle (drawn by the renderer;
    /// full-length ones may also be houses).
    public let diagonals: [[Int]]
    /// Pairwise-distinct groups that need NOT contain every digit — argyle's
    /// short diagonals. Unlike houses these never feed hidden-single logic;
    /// they only widen each member's peer set.
    public let cliques: [[Int]]

    /// Row-major lookup table: position → cell index, -1 where inactive.
    private let indexByPosition: [Int]

    public init(
        variant: SudokuVariant,
        size: Int,
        rowCount: Int,
        colCount: Int,
        cells: [GridPosition],
        houses: [[Int]],
        houseKinds: [HouseKind],
        boxIndex: [Int],
        windows: [[Int]] = [],
        diagonals: [[Int]] = [],
        cliques: [[Int]] = [],
    ) {
        self.variant = variant
        self.size = size
        self.rowCount = rowCount
        self.colCount = colCount
        self.cells = cells
        self.houses = houses
        self.houseKinds = houseKinds
        self.boxIndex = boxIndex
        self.windows = windows
        self.diagonals = diagonals
        self.cliques = cliques

        var lookup = [Int](repeating: -1, count: rowCount * colCount)
        for (index, position) in cells.enumerated() {
            lookup[position.row * colCount + position.col] = index
        }
        indexByPosition = lookup
    }

    public var cellCount: Int {
        cells.count
    }

    /// The cell index at a grid position, or nil where no cell exists.
    public func index(row: Int, col: Int) -> Int? {
        guard row >= 0, row < rowCount, col >= 0, col < colCount else { return nil }
        let mapped = indexByPosition[row * colCount + col]
        return mapped >= 0 ? mapped : nil
    }

    public func position(of index: Int) -> GridPosition {
        cells[index]
    }
}
