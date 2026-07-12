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

    /// A typed format argument, so Presentation can render digits through a
    /// variant's glyph set (hexadoku's 0–F, wordoku's letters) instead of the
    /// engine baking digit strings into the message.
    public enum Argument: Equatable, Sendable, Codable {
        case digit(Int)
        case digits([Int])
        /// One-based, display-ready coordinates.
        case row(Int)
        case column(Int)
    }

    public let kind: Kind
    /// Cells the UI should spotlight while explaining the step.
    public let cells: [Int]
    public let placement: Placement?
    public let eliminations: [Elimination]
    /// Localization key for the human-readable explanation (resolved by
    /// Presentation against its string catalog), plus its format arguments.
    public let explanationKey: String
    public let explanationArguments: [Argument]

    public init(
        kind: Kind,
        cells: [Int],
        placement: Placement? = nil,
        eliminations: [Elimination] = [],
        explanationKey: String,
        explanationArguments: [Argument] = [],
    ) {
        self.kind = kind
        self.cells = cells
        self.placement = placement
        self.eliminations = eliminations
        self.explanationKey = explanationKey
        self.explanationArguments = explanationArguments
    }
}
