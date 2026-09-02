import Model

/// A whole cube: six 3×3 faces, each a full house, with every row and
/// column continuing straight across the twelve edges as a 6-cell clique.
/// Nothing else constrains the puzzle — the rings of four faces around the
/// cube cannot be houses (12 cells, 9 digits). Played on `CubeNet`'s cross
/// net, so the topology is an ordinary bounding box with inactive corners.
enum CubeTopology {
    static func build() -> GridTopology {
        let cells = (0 ..< CubeNet.cellCount).map(CubeNet.netPosition)
        let houses = CubeNet.Face.allCases.map { face in
            (0 ..< CubeNet.cellsPerFace).map { face.rawValue * CubeNet.cellsPerFace + $0 }
        }
        return GridTopology(
            variant: .cube,
            size: 9,
            rowCount: CubeNet.netRows,
            colCount: CubeNet.netCols,
            cells: cells,
            houses: houses,
            houseKinds: [HouseKind](repeating: .box, count: houses.count),
            boxIndex: (0 ..< CubeNet.cellCount).map { $0 / CubeNet.cellsPerFace },
            cliques: CubeNet.bentLines(),
        )
    }
}
