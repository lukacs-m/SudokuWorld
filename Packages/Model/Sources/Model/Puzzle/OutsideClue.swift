/// A clue printed outside the grid: sandwich sums, skyscraper counts, and
/// little-killer diagonal sums. `side` names the edge the clue sits on and
/// `offset` the row/column along that edge.
///
/// Little-killer diagonals read from their edge cell inward, one fixed
/// direction per side: top ↘, trailing ↙, bottom ↖, leading ↗ — between
/// them the four sides reach every diagonal from either end.
public struct OutsideClue: Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case sandwichSum = "sandwich"
        case skyscraperCount = "skyscraper"
        case diagonalSum = "littlekiller"
    }

    public enum Side: String, Sendable, Codable {
        case top
        case bottom
        case leading
        case trailing
    }

    public let kind: Kind
    public let side: Side
    public let offset: Int
    public let value: Int

    public init(kind: Kind, side: Side, offset: Int, value: Int) {
        self.kind = kind
        self.side = side
        self.offset = offset
        self.value = value
    }
}
