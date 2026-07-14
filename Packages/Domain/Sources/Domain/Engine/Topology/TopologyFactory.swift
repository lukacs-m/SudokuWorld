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

    // swiftlint:disable:next cyclomatic_complexity
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
        case .gattai2: gattai2Topology
        case .gattai3: gattai3Topology
        case .gattai8: gattai8Topology
        case .shogun: shogunTopology
        case .sumo: sumoTopology
        case .alphadoku25: alphadoku25Topology
        case .antiKnight: antiKnightTopology
        case .antiKing: antiKingTopology
        case .greaterThan: greaterThanTopology
        case .kropki: kropkiTopology
        case .xv: xvTopology
        case .consecutive: consecutiveTopology
        case .miracle: miracleTopology
        case .thermo: thermoTopology
        case .arrow: arrowTopology
        case .sandwich: sandwichTopology
        case .skyscraper: skyscraperTopology
        case .littleKiller: littleKillerTopology
        case .fogOfWar: fogOfWarTopology
        case .killerGT: killerGTTopology
        case .tredoku: tredokuTopology
        }
    }
}

// MARK: - Cached shapes

extension TopologyFactory {
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
    /// Multi-grid layouts: origins sit on multiples of 6 so overlaps land on
    /// whole 3×3 boxes.
    private static let samuraiTopology = OverlappingGrids.build(
        variant: .samurai,
        origins: [(0, 0), (0, 12), (6, 6), (12, 0), (12, 12)],
        spanRows: 21,
        spanCols: 21,
    )
    private static let gattai2Topology = OverlappingGrids.build(
        variant: .gattai2,
        origins: [(0, 0), (6, 6)],
        spanRows: 15,
        spanCols: 15,
    )
    private static let gattai3Topology = OverlappingGrids.build(
        variant: .gattai3,
        origins: [(0, 0), (6, 6), (12, 12)],
        spanRows: 21,
        spanCols: 21,
    )
    private static let gattai8Topology = OverlappingGrids.build(
        variant: .gattai8,
        origins: [
            (0, 0), (0, 12), (0, 24),
            (6, 6), (6, 18),
            (12, 0), (12, 12), (12, 24),
        ],
        spanRows: 21,
        spanCols: 33,
    )
    private static let shogunTopology = OverlappingGrids.build(
        variant: .shogun,
        origins: [
            (0, 0), (0, 12), (0, 24), (0, 36),
            (6, 6), (6, 18), (6, 30),
            (12, 0), (12, 12), (12, 24), (12, 36),
        ],
        spanRows: 21,
        spanCols: 45,
    )
    private static let sumoTopology = OverlappingGrids.build(
        variant: .sumo,
        origins: [
            (0, 0), (0, 12), (0, 24),
            (6, 6), (6, 18),
            (12, 0), (12, 12), (12, 24),
            (18, 6), (18, 18),
            (24, 0), (24, 12), (24, 24),
        ],
        spanRows: 33,
        spanCols: 33,
    )
    private static let mini4Topology = rectangular(variant: .mini4, size: 4, boxRows: 2, boxCols: 2)
    private static let alphadoku25Topology = rectangular(
        variant: .alphadoku25,
        size: 25,
        boxRows: 5,
        boxCols: 5,
    )
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

    /// Chess variants: classic houses plus a "sees" pair for every knight
    /// move (anti-knight) or diagonal-touch (anti-king; orthogonal touches
    /// already share a row or column). Each pair is a 2-cell clique, so the
    /// whole engine inherits the rule through the widened peer sets — no
    /// overlay renders because these variants carry no visual marks.
    private static let antiKnightTopology: GridTopology = {
        let base = rectangular(variant: .antiKnight, size: 9, boxRows: 3, boxCols: 3)
        return withCliques(base, movePairs(size: 9, offsets: [
            (1, 2), (1, -2), (2, 1), (2, -1),
        ]))
    }()

    private static let antiKingTopology: GridTopology = {
        let base = rectangular(variant: .antiKing, size: 9, boxRows: 3, boxCols: 3)
        return withCliques(base, movePairs(size: 9, offsets: [(1, 1), (1, -1)]))
    }()

    /// Relation-clue variants share the classic shape; their marks are
    /// per-puzzle data on PuzzleDefinition.
    private static let greaterThanTopology = rectangular(
        variant: .greaterThan,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let kropkiTopology = rectangular(
        variant: .kropki,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let xvTopology = rectangular(variant: .xv, size: 9, boxRows: 3, boxCols: 3)
    private static let thermoTopology = rectangular(
        variant: .thermo,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let arrowTopology = rectangular(
        variant: .arrow,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let sandwichTopology = rectangular(
        variant: .sandwich,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let skyscraperTopology = rectangular(
        variant: .skyscraper,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let littleKillerTopology = rectangular(
        variant: .littleKiller,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    /// Fog of war plays a classic board; the fog is session state, not
    /// structure or constraint.
    private static let fogOfWarTopology = rectangular(
        variant: .fogOfWar,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let killerGTTopology = rectangular(
        variant: .killerGT,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )
    private static let tredokuTopology = TredokuTopology.build()
    private static let consecutiveTopology = rectangular(
        variant: .consecutive,
        size: 9,
        boxRows: 3,
        boxCols: 3,
    )

    /// Miracle: anti-knight + anti-king cliques; the third rule (orthogonal
    /// neighbors are never consecutive) is a relation constraint expanded
    /// from the variant, not structure.
    private static let miracleTopology: GridTopology = {
        let base = rectangular(variant: .miracle, size: 9, boxRows: 3, boxCols: 3)
        let knight = movePairs(size: 9, offsets: [(1, 2), (1, -2), (2, 1), (2, -1)])
        let king = movePairs(size: 9, offsets: [(1, 1), (1, -1)])
        return withCliques(base, knight + king)
    }()

    /// Every unordered in-bounds cell pair reachable by one of the given
    /// canonical offsets (offsets must not contain both a move and its
    /// inverse, or pairs would double).
    private static func movePairs(size: Int, offsets: [(Int, Int)]) -> [[Int]] {
        var pairs: [[Int]] = []
        for row in 0 ..< size {
            for col in 0 ..< size {
                for (rowDelta, colDelta) in offsets {
                    let targetRow = row + rowDelta
                    let targetCol = col + colDelta
                    guard targetRow >= 0, targetRow < size,
                          targetCol >= 0, targetCol < size else { continue }
                    pairs.append([row * size + col, targetRow * size + targetCol])
                }
            }
        }
        return pairs
    }

    private static func withCliques(_ base: GridTopology, _ cliques: [[Int]]) -> GridTopology {
        GridTopology(
            variant: base.variant,
            size: base.size,
            rowCount: base.rowCount,
            colCount: base.colCount,
            cells: base.cells,
            houses: base.houses,
            houseKinds: base.houseKinds,
            boxIndex: base.boxIndex,
            cliques: cliques,
        )
    }

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
        let boxIndex = appendBoxes(
            to: &houses,
            kinds: &kinds,
            size: size,
            boxRows: boxRows,
            boxCols: boxCols,
        )

        var diagonals: [[Int]] = []
        if includeDiagonals {
            let main = (0 ..< size).map { $0 * size + $0 }
            let anti = (0 ..< size).map { $0 * size + (size - 1 - $0) }
            diagonals = [main, anti]
            houses.append(contentsOf: diagonals)
            kinds.append(contentsOf: [.diagonal, .diagonal])
        }
        let windows = includeWindows
            ? appendWindows(to: &houses, kinds: &kinds, size: size)
            : []

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

    /// Appends the box houses and returns the per-cell box map.
    private static func appendBoxes(
        to houses: inout [[Int]],
        kinds: inout [HouseKind],
        size: Int,
        boxRows: Int,
        boxCols: Int,
    ) -> [Int] {
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
        return boxIndex
    }

    /// Appends windoku's four 3×3 windows (rows/cols 1-3 and 5-7).
    private static func appendWindows(
        to houses: inout [[Int]],
        kinds: inout [HouseKind],
        size: Int,
    ) -> [[Int]] {
        var windows: [[Int]] = []
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
        return windows
    }
}
