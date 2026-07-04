import Model

/// The samurai layout: five overlapping 9×9 grids in a 21×21 bounding box.
/// The four corner grids each share one 3×3 box with the center grid, giving
/// 369 active cells and 131 distinct houses (45 rows + 45 columns + 41 boxes
/// after deduplicating the 4 shared boxes).
enum SamuraiTopology {
    /// Top-left origins of the five sub-grids.
    static let gridOrigins: [(row: Int, col: Int)] = [
        (0, 0), (0, 12), (6, 6), (12, 0), (12, 12),
    ]
    static let span = 21

    static func build() -> GridTopology {
        var active = [Bool](repeating: false, count: span * span)
        for origin in gridOrigins {
            for row in origin.row ..< (origin.row + 9) {
                for col in origin.col ..< (origin.col + 9) {
                    active[row * span + col] = true
                }
            }
        }

        var cells: [GridPosition] = []
        var indexAt = [Int](repeating: -1, count: span * span)
        for row in 0 ..< span {
            for col in 0 ..< span where active[row * span + col] {
                indexAt[row * span + col] = cells.count
                cells.append(GridPosition(row: row, col: col))
            }
        }

        var houses: [[Int]] = []
        var kinds: [HouseKind] = []
        var boxIndex = [Int](repeating: -1, count: cells.count)
        var seenBoxes = Set<[Int]>()
        var nextBoxId = 0

        for origin in gridOrigins {
            for row in 0 ..< 9 {
                houses
                    .append((0 ..< 9).map { indexAt[(origin.row + row) * span + origin.col + $0] })
                kinds.append(.row)
            }
            for col in 0 ..< 9 {
                houses
                    .append((0 ..< 9).map { indexAt[(origin.row + $0) * span + origin.col + col] })
                kinds.append(.column)
            }
            for boxRow in 0 ..< 3 {
                for boxCol in 0 ..< 3 {
                    var box: [Int] = []
                    for row in 0 ..< 3 {
                        for col in 0 ..< 3 {
                            let position = (origin.row + boxRow * 3 + row) * span
                                + (origin.col + boxCol * 3 + col)
                            box.append(indexAt[position])
                        }
                    }
                    guard seenBoxes.insert(box).inserted else { continue }
                    houses.append(box)
                    kinds.append(.box)
                    for cell in box where boxIndex[cell] == -1 {
                        boxIndex[cell] = nextBoxId
                    }
                    nextBoxId += 1
                }
            }
        }

        return GridTopology(
            variant: .samurai,
            size: 9,
            rowCount: span,
            colCount: span,
            cells: cells,
            houses: houses,
            houseKinds: kinds,
            boxIndex: boxIndex,
        )
    }
}
