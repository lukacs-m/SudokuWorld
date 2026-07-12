/// The playable rule sets. Raw values are the canonical slugs used in
/// Game Center identifiers and persistence — renaming a case must never change
/// its slug (a unit test pins the full slug table). Every case is fully
/// playable: a new case only lands together with its engine support.
public enum SudokuVariant: String, CaseIterable, Equatable, Sendable, Codable {
    case classic
    case mini6
    case killer
    case diagonal
    case windoku
    case evenOdd = "evenodd"
    case samurai

    /// Stable identifier used in leaderboard IDs and persistence.
    public var slug: String {
        rawValue
    }

    /// The catalog section this variant is displayed under.
    public var group: SudokuVariantGroup {
        switch self {
        case .classic, .mini6: .gridSizes
        case .killer, .diagonal, .windoku: .extraRegions
        case .samurai: .multiGrid
        case .evenOdd: .twists
        }
    }

    /// Killer puzzles replace most givens with cage-sum constraints.
    public var usesCages: Bool {
        self == .killer
    }

    /// Even-Odd puzzles constrain marked cells to a parity.
    public var usesParity: Bool {
        self == .evenOdd
    }
}
