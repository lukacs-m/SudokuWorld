import Model

/// Builds any gattai-style layout: several 9×9 grids in one bounding box,
/// overlapping on whole 3×3 boxes. Every grid contributes its own rows,
/// columns, and boxes; boxes covering identical cells (the overlaps) are
/// deduplicated. Positions covered by no grid stay inactive, and the
/// renderer's "bold rim where there's no active neighbor" handles the
/// ragged outline for free — samurai proved the whole pipeline.
enum OverlappingGrids {
    static func build(
        variant: SudokuVariant,
        origins: [(row: Int, col: Int)],
        spanRows: Int,
        spanCols: Int,
    ) -> GridTopology {
        var active = [Bool](repeating: false, count: spanRows * spanCols)
        for origin in origins {
            for row in origin.row ..< (origin.row + 9) {
                for col in origin.col ..< (origin.col + 9) {
                    active[row * spanCols + col] = true
                }
            }
        }

        var cells: [GridPosition] = []
        var indexAt = [Int](repeating: -1, count: spanRows * spanCols)
        for row in 0 ..< spanRows {
            for col in 0 ..< spanCols where active[row * spanCols + col] {
                indexAt[row * spanCols + col] = cells.count
                cells.append(GridPosition(row: row, col: col))
            }
        }

        var houses: [[Int]] = []
        var kinds: [HouseKind] = []
        var boxIndex = [Int](repeating: -1, count: cells.count)
        var seenBoxes = Set<[Int]>()
        var nextBoxId = 0

        for origin in origins {
            for row in 0 ..< 9 {
                houses.append((0 ..< 9).map {
                    indexAt[(origin.row + row) * spanCols + origin.col + $0]
                })
                kinds.append(.row)
            }
            for col in 0 ..< 9 {
                houses.append((0 ..< 9).map {
                    indexAt[(origin.row + $0) * spanCols + origin.col + col]
                })
                kinds.append(.column)
            }
            for boxRow in 0 ..< 3 {
                for boxCol in 0 ..< 3 {
                    var box: [Int] = []
                    for row in 0 ..< 3 {
                        for col in 0 ..< 3 {
                            let position = (origin.row + boxRow * 3 + row) * spanCols
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
            variant: variant,
            size: 9,
            rowCount: spanRows,
            colCount: spanCols,
            cells: cells,
            houses: houses,
            houseKinds: kinds,
            boxIndex: boxIndex,
        )
    }
}
