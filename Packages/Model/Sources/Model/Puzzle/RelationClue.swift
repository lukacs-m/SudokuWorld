/// A visible pairwise mark between two adjacent cells: kropki dots, XV
/// letters, futoshiki inequalities, consecutive bars. Cells are indices into
/// the puzzle's topology; the mark's meaning always reads a-to-b.
public struct RelationClue: Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        /// value(a) > value(b).
        case greaterThan = "gt"
        /// |a − b| == 1, kropki white dot.
        case whiteDot = "white"
        /// One value is double the other, kropki black dot.
        case blackDot = "black"
        /// a + b == 10.
        case xSum = "x"
        /// a + b == 5.
        case vSum = "v"
        /// |a − b| == 1, consecutive-sudoku bar.
        case consecutive = "bar"
    }

    public let a: Int
    public let b: Int
    public let kind: Kind

    public init(a: Int, b: Int, kind: Kind) {
        self.a = a
        self.b = b
        self.kind = kind
    }
}
