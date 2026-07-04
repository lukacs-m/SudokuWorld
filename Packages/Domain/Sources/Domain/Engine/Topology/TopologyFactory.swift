public import Model

/// Builds and caches the structural grid for each variant. Killer and
/// Even-Odd share the classic shape — their extra constraints (cages,
/// parity marks) are per-puzzle data, not structure.
public enum TopologyFactory {
    public static func topology(for variant: SudokuVariant) -> GridTopology {
        switch variant {
        case .classic: classicTopology
        case .mini6: mini6Topology
        case .killer: killerTopology
        case .diagonal: diagonalTopology
        case .windoku: windokuTopology
        case .evenOdd: evenOddTopology
        case .samurai: samuraiTopology
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
