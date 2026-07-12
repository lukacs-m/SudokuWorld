/// A cell's location in a topology's bounding box, in grid coordinates.
public struct GridPosition: Hashable, Sendable, Codable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}
