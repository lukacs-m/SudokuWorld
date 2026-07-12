/// A killer-sudoku cage: a connected group of cells whose values must be
/// distinct and add up to `sum`.
public struct Cage: Hashable, Sendable, Codable {
    public let cells: [Int]
    public let sum: Int

    public init(cells: [Int], sum: Int) {
        self.cells = cells
        self.sum = sum
    }
}
