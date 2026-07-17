import Model

/// The smallest tredoku layout: three 3×3 faces meeting at a corner, played
/// unfolded — face A top-left, face B to its right, face C below. Each face
/// holds the digits 1–9 once (a full house); the tredoku "bent line" rule —
/// no repeats along a line that continues across a fold — maps onto cliques
/// spanning A→B rows and A→C columns. The renderer needs nothing new: bold
/// borders follow face ids and the empty corner stays inactive, exactly like
/// a samurai's ragged outline.
enum TredokuTopology {
    static func build() -> GridTopology {
        let span = 6
        var active = [Bool](repeating: false, count: span * span)
        for row in 0 ..< 3 {
            for col in 0 ..< 6 {
                active[row * span + col] = true // faces A + B
            }
        }
        for row in 3 ..< 6 {
            for col in 0 ..< 3 {
                active[row * span + col] = true // face C
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
        var boxIndex = [Int](repeating: -1, count: cells.count)
        let faceOrigins = [(0, 0), (0, 3), (3, 0)]
        for (face, origin) in faceOrigins.enumerated() {
            var box: [Int] = []
            for row in 0 ..< 3 {
                for col in 0 ..< 3 {
                    let index = indexAt[(origin.0 + row) * span + origin.1 + col]
                    box.append(index)
                    boxIndex[index] = face
                }
            }
            houses.append(box)
        }

        var cliques: [[Int]] = []
        for row in 0 ..< 3 {
            cliques.append((0 ..< 6).map { indexAt[row * span + $0] }) // A→B rows
        }
        for col in 0 ..< 3 {
            cliques.append((0 ..< 6).map { indexAt[$0 * span + col] }) // A→C columns
        }

        return GridTopology(
            variant: .tredoku,
            size: 9,
            rowCount: span,
            colCount: span,
            cells: cells,
            houses: houses,
            houseKinds: [HouseKind](repeating: .box, count: houses.count),
            boxIndex: boxIndex,
            cliques: cliques,
        )
    }
}
