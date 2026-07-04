/// A structured next step from the hint engine: either the application of a
/// logical technique (with an explanation) or a straight solution reveal.
public struct Hint: Equatable, Sendable, Codable {
    public enum Kind: Equatable, Sendable, Codable {
        case logical(Technique)
        case reveal
    }

    /// A digit to write into a cell.
    public struct Placement: Equatable, Sendable, Codable {
        public let index: Int
        public let digit: Int

        public init(index: Int, digit: Int) {
            self.index = index
            self.digit = digit
        }
    }

    /// A candidate that the technique proves impossible.
    public struct Elimination: Equatable, Sendable, Codable {
        public let index: Int
        public let digit: Int

        public init(index: Int, digit: Int) {
            self.index = index
            self.digit = digit
        }
    }

    public let kind: Kind
    /// Cells the UI should spotlight while explaining the step.
    public let cells: [Int]
    public let placement: Placement?
    public let eliminations: [Elimination]
    /// Localization key for the human-readable explanation (resolved by
    /// Presentation against its string catalog), plus its format arguments.
    public let explanationKey: String
    public let explanationArgs: [String]

    public init(
        kind: Kind,
        cells: [Int],
        placement: Placement? = nil,
        eliminations: [Elimination] = [],
        explanationKey: String,
        explanationArgs: [String] = [],
    ) {
        self.kind = kind
        self.cells = cells
        self.placement = placement
        self.eliminations = eliminations
        self.explanationKey = explanationKey
        self.explanationArgs = explanationArgs
    }
}
