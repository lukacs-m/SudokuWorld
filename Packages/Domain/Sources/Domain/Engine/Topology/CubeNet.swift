public import Model

/// The cube variant's single source of structure: six 3×3 faces laid out as
/// a cross net, plus the twelve folded edges with their orientation. Both
/// the engine (cliques) and the 3D board (cell placement, accessibility)
/// read the cell ↔ (face, row, col) mapping from here, so they can never
/// disagree about which cell is where.
///
/// Net layout (rows 0–8, cols 0–11), one letter per face:
///
///          U
///      L   F   R   B
///          D
///
/// Cell indices run face-major: `face * 9 + row * 3 + col`, faces in
/// `Face` declaration order.
public enum CubeNet {
    public enum Face: Int, CaseIterable, Sendable {
        case up
        case left
        case front
        case right
        case back
        case down

        /// Stable slug for localization keys.
        public var slug: String {
            switch self {
            case .up: "up"
            case .left: "left"
            case .front: "front"
            case .right: "right"
            case .back: "back"
            case .down: "down"
            }
        }

        /// Top-left corner of the face on the net.
        var netOrigin: (row: Int, col: Int) {
            switch self {
            case .up: (0, 3)
            case .left: (3, 0)
            case .front: (3, 3)
            case .right: (3, 6)
            case .back: (3, 9)
            case .down: (6, 3)
            }
        }
    }

    /// One border of a face. Its three boundary cells are numbered 0...2
    /// left→right for top/bottom and top→bottom for left/right.
    public enum Side: Sendable {
        case top
        case bottom
        case left
        case right
    }

    /// Two face sides glued together on the cube. Boundary cell `k` of
    /// `sideA` touches boundary cell `k` of `sideB`, or `2 - k` when
    /// `flipped`, so a row or column leaving one face continues straight
    /// onto the other.
    public struct Edge: Sendable {
        public let faceA: Face
        public let sideA: Side
        public let faceB: Face
        public let sideB: Side
        public let flipped: Bool

        public func matchingBoundaryCell(_ k: Int) -> Int {
            flipped ? 2 - k : k
        }
    }

    public static let cellsPerFace = 9
    public static let cellCount = 54
    public static let netRows = 9
    public static let netCols = 12

    /// The twelve edges of the cube. The five net-adjacent pairs are the
    /// unflipped ones that share a net line; the rest are the folds.
    public static let edges: [Edge] = [
        Edge(faceA: .up, sideA: .left, faceB: .left, sideB: .top, flipped: false),
        Edge(faceA: .up, sideA: .bottom, faceB: .front, sideB: .top, flipped: false),
        Edge(faceA: .up, sideA: .right, faceB: .right, sideB: .top, flipped: true),
        Edge(faceA: .up, sideA: .top, faceB: .back, sideB: .top, flipped: true),
        Edge(faceA: .left, sideA: .right, faceB: .front, sideB: .left, flipped: false),
        Edge(faceA: .left, sideA: .left, faceB: .back, sideB: .right, flipped: false),
        Edge(faceA: .left, sideA: .bottom, faceB: .down, sideB: .left, flipped: true),
        Edge(faceA: .front, sideA: .right, faceB: .right, sideB: .left, flipped: false),
        Edge(faceA: .front, sideA: .bottom, faceB: .down, sideB: .top, flipped: false),
        Edge(faceA: .right, sideA: .right, faceB: .back, sideB: .left, flipped: false),
        Edge(faceA: .right, sideA: .bottom, faceB: .down, sideB: .right, flipped: false),
        Edge(faceA: .back, sideA: .bottom, faceB: .down, sideB: .bottom, flipped: true),
    ]

    public static func index(face: Face, row: Int, col: Int) -> Int {
        face.rawValue * cellsPerFace + row * 3 + col
    }

    public static func facePosition(of index: Int) -> (face: Face, row: Int, col: Int) {
        let face = Face(rawValue: index / cellsPerFace) ?? .up
        let offset = index % cellsPerFace
        return (face, offset / 3, offset % 3)
    }

    public static func netPosition(of index: Int) -> GridPosition {
        let (face, row, col) = facePosition(of: index)
        let origin = face.netOrigin
        return GridPosition(row: origin.row + row, col: origin.col + col)
    }

    /// The three cells of the line that leaves `face` through boundary
    /// cell `k` of `side`, ordered from the far end toward that side.
    static func line(face: Face, side: Side, boundaryCell k: Int) -> [Int] {
        let cells: [(Int, Int)] = switch side {
        case .top: [(2, k), (1, k), (0, k)]
        case .bottom: [(0, k), (1, k), (2, k)]
        case .left: [(k, 2), (k, 1), (k, 0)]
        case .right: [(k, 0), (k, 1), (k, 2)]
        }
        return cells.map { index(face: face, row: $0.0, col: $0.1) }
    }

    /// Every bent line: for each edge and each of its three boundary
    /// cells, the line on one face followed by its continuation on the
    /// other, ordered end to end.
    static func bentLines() -> [[Int]] {
        edges.flatMap { edge in
            (0 ..< 3).map { k in
                line(face: edge.faceA, side: edge.sideA, boundaryCell: k)
                    + line(
                        face: edge.faceB,
                        side: edge.sideB,
                        boundaryCell: edge.matchingBoundaryCell(k),
                    ).reversed()
            }
        }
    }
}
