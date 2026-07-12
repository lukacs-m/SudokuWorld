public import Model

/// Builds and caches the structural grid for each variant. Killer and
/// Even-Odd share the classic shape — their extra constraints (cages,
/// parity marks) are per-puzzle data, not structure.
public enum TopologyFactory {
    /// The shape of a specific puzzle: honors per-puzzle structure (jigsaw
    /// region maps) and falls back to the variant's cached topology. Prefer
    /// this overload anywhere a `PuzzleDefinition` is in hand.
    public static func topology(for puzzle: PuzzleDefinition) -> GridTopology {
        if let boxes = puzzle.irregularBoxes {
            return JigsawTopology.build(boxes: boxes)
        }
        return topology(for: puzzle.variant)
    }

    public static func topology(for variant: SudokuVariant) -> GridTopology {
        switch variant {
        case .classic: classicTopology
        case .mini6: mini6Topology
        case .killer: killerTopology
        case .diagonal: diagonalTopology
        case .windoku: windokuTopology
        case .evenOdd: evenOddTopology
        case .samurai: samuraiTopology
        case .mini4: mini4Topology
        case .dodeka12: dodeka12Topology
        case .hexadoku16: hexadoku16Topology
        case .wordoku: wordokuTopology
        // Jigsaw's real shape is per-puzzle (`irregularBoxes`); this
        // classic-box stand-in only sizes budgets before generation.
        case .jigsaw: jigsawFallbackTopology
        case .argyle: argyleTopology
        case .asterisk: asteriskTopology
        }
    }

    private static let classicTopology = rectangular(
        variant: .classic,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let killerTopology = rectangular(
        variant: .killer,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let evenOddTopology = rectangular(
        variant: .evenOdd,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let mini6Topology = rectangular(variant: .mini6, size: 6, boxRows: 2, boxCols: 3)
    private static let diagonalTopology = rectangular(
        variant: .diagonal,
        size: 9,
        boxRows: 3,
        boxCols: 3,
        includeDiagonals: true,
    )
    private static let windokuTopology = rectangular(
        variant: .windoku,
        size: 9,
        boxRows: 3,
        boxCols: 3,
        includeWindows: true,
    )
    private static let samuraiTopology = SamuraiTopology.build()
    private static let mini4Topology = rectangular(variant: .mini4, size: 4, boxRows: 2, boxCols: 2)
    private static let dodeka12Topology = rectangular(
        variant: .dodeka12,
        size: 12,
        boxRows: 3,
        boxCols: 4,
    )
    private static let hexadoku16Topology = rectangular(
        variant: .hexadoku16,
        size: 16,
        boxRows: 4,
        boxCols: 4,
    )
    /// Wordoku is a classic 9×9 under letter glyphs; the glyph mapping is
    /// purely presentational.
    private static let wordokuTopology = rectangular(
        variant: .wordoku,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let jigsawFallbackTopology = rectangular(
        variant: .jigsaw,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )

    /// Argyle: classic houses plus six marked diagonals — the two main
    /// diagonals and the four edges of the inscribed diamond. The short
    /// lines can't be houses (a house must contain every digit), so they
    /// ride as `cliques`: pairwise-distinct groups feeding only the peer
    /// sets. `diagonals` carries the same lines for rendering.
    private static let argyleTopology: GridTopology = {
        let base = rectangular(variant: .argyle, size: 9, boxRows: 3, boxCols: 3)
        var lines: [[Int]] = [
            (0 ... 8).map { $0 * 9 + $0 },
            (0 ... 8).map { $0 * 9 + (8 - $0) },
        ]
        lines.append((0 ... 4).map { $0 * 9 + ($0 + 4) }) // NE diamond edge
        lines.append((0 ... 4).map { $0 * 9 + (4 - $0) }) // NW
        lines.append((4 ... 8).map { $0 * 9 + (12 - $0) }) // SE
        lines.append((4 ... 8).map { $0 * 9 + ($0 - 4) }) // SW
        return GridTopology(
            variant: .argyle,
            size: 9,
            rowCount: 9,
            colCount: 9,
            cells: base.cells,
            houses: base.houses,
            houseKinds: base.houseKinds,
            boxIndex: base.boxIndex,
            diagonals: lines,
            cliques: lines,
        )
    }()

    /// Asterisk: classic houses plus one scattered 9-cell region (a full
    /// house — it contains every digit), shaded like a windoku window.
    private static let asteriskTopology: GridTopology = {
        let base = rectangular(variant: .asterisk, size: 9, boxRows: 3, boxCols: 3)
        let star = [
            (1, 4), (2, 2), (2, 6),
            (4, 1), (4, 4), (4, 7),
            (6, 2), (6, 6), (7, 4),
        ].map { $0.0 * 9 + $0.1 }
        return GridTopology(
            variant: .asterisk,
            size: 9,
            rowCount: 9,
            colCount: 9,
            cells: base.cells,
            houses: base.houses + [star],
            houseKinds: base.houseKinds + [.window],
            boxIndex: base.boxIndex,
            windows: [star],
        )
    }()

    /// A full square grid of `size`×`size` with `boxRows`×`boxCols` boxes,
    /// optionally decorated with diagonal or windoku houses.
    private static func rectangular(
        variant: SudokuVariant,
        size: Int,
        boxRows: Int,
        boxCols: Int,
        includeDiagonals: Bool = false,
        includeWindows: Bool = false,
    ) -> GridTopology {
        var cells: [GridPosition] = []
        for row in 0 ..< size {
            for col in 0 ..< size {
                cells.append(GridPosition(row: row, col: col))
            }
        }

        var houses: [[Int]] = []
        var kinds: [HouseKind] = []
        for row in 0 ..< size {
            houses.append((0 ..< size).map { row * size + $0 })
            kinds.append(.row)
        }
        for col in 0 ..< size {
            houses.append((0 ..< size).map { $0 * size + col })
            kinds.append(.column)
        }

        let boxesPerRow = size / boxCols
        var boxIndex = [Int](repeating: 0, count: size * size)
        for boxId in 0 ..< size {
            let originRow = (boxId / boxesPerRow) * boxRows
            let originCol = (boxId % boxesPerRow) * boxCols
            var box: [Int] = []
            for row in 0 ..< boxRows {
                for col in 0 ..< boxCols {
                    let cell = (originRow + row) * size + (originCol + col)
                    box.append(cell)
                    boxIndex[cell] = boxId
                }
            }
            houses.append(box)
            kinds.append(.box)
        }

        var diagonals: [[Int]] = []
        if includeDiagonals {
            let main = (0 ..< size).map { $0 * size + $0 }
            let anti = (0 ..< size).map { $0 * size + (size - 1 - $0) }
            diagonals = [main, anti]
            houses.append(contentsOf: diagonals)
            kinds.append(contentsOf: [.diagonal, .diagonal])
        }

        var windows: [[Int]] = []
        if includeWindows {
            // The four 3×3 windows of a windoku, at rows/cols 1-3 and 5-7.
            for originRow in [1, 5] {
                for originCol in [1, 5] {
                    var window: [Int] = []
                    for row in 0 ..< 3 {
                        for col in 0 ..< 3 {
                            window.append((originRow + row) * size + (originCol + col))
                        }
                    }
                    windows.append(window)
                    houses.append(window)
                    kinds.append(.window)
                }
            }
        }

        return GridTopology(
            variant: variant,
            size: size,
            rowCount: size,
            colCount: size,
            cells: cells,
            houses: houses,
            houseKinds: kinds,
            boxIndex: boxIndex,
            windows: windows,
            diagonals: diagonals,
        )
    }
}
