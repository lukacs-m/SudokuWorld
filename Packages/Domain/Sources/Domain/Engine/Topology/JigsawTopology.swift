public import Model

/// Builds a jigsaw grid from a per-puzzle region assignment: standard rows
/// and columns, with the irregular regions taking the place of boxes. The
/// renderer draws region borders straight off `boxIndex`, so no jigsaw-
/// specific drawing exists anywhere.
public enum JigsawTopology {
    public static func build(boxes: [Int]) -> GridTopology {
        let cellCount = boxes.count
        let size = Int(Double(cellCount).squareRoot())
        precondition(size * size == cellCount, "jigsaw region map must be square")

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
        var regions = [[Int]](repeating: [], count: size)
        for (cell, region) in boxes.enumerated() {
            regions[region].append(cell)
        }
        houses.append(contentsOf: regions)
        kinds.append(contentsOf: [HouseKind](repeating: .box, count: size))

        return GridTopology(
            variant: .jigsaw,
            size: size,
            rowCount: size,
            colCount: size,
            cells: cells,
            houses: houses,
            houseKinds: kinds,
            boxIndex: boxes,
        )
    }
}
