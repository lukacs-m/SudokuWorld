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
    case mini4
    case dodeka12
    case hexadoku16
    case wordoku
    case jigsaw
    case argyle
    case asterisk
    case gattai2
    case gattai3
    case gattai8
    case shogun
    case sumo
    case alphadoku25
    case antiKnight = "antiknight"
    case antiKing = "antiking"
    case greaterThan = "greaterthan"
    case kropki
    case xv
    case consecutive
    case miracle
    case thermo
    case arrow
    case sandwich
    case skyscraper
    case littleKiller = "littlekiller"
    case fogOfWar = "fogofwar"
    case killerGT = "killergt"
    case tredoku
    case cube

    /// Stable identifier used in leaderboard IDs and persistence.
    public var slug: String {
        rawValue
    }

    /// The catalog section this variant is displayed under.
    public var group: SudokuVariantGroup {
        switch self {
        case .mini4, .mini6, .classic, .dodeka12, .hexadoku16, .alphadoku25: .gridSizes
        case .killer, .diagonal, .windoku, .jigsaw, .argyle, .asterisk: .extraRegions
        case .greaterThan, .kropki, .xv, .consecutive, .thermo, .arrow,
             .sandwich, .skyscraper, .littleKiller: .relationClues
        case .antiKnight, .antiKing, .miracle: .chess
        case .samurai, .gattai2, .gattai3, .gattai8, .shogun, .sumo: .multiGrid
        case .evenOdd, .wordoku, .fogOfWar, .killerGT, .tredoku, .cube: .twists
        }
    }

    /// Killer puzzles replace most givens with cage-sum constraints.
    public var usesCages: Bool {
        self == .killer || self == .killerGT
    }

    /// Even-Odd puzzles constrain marked cells to a parity.
    public var usesParity: Bool {
        self == .evenOdd
    }
}

public extension SudokuVariant {
    /// The tiers a player may be assigned, in ascending order. The fold
    /// variants omit the tiers their honest grading cannot reach (the survey
    /// behind PR 11), so no puzzle is served under a label it does not earn.
    var offeredDifficulties: [Difficulty] {
        switch self {
        case .tredoku: [.beginner, .easy, .hard]
        case .cube: [.beginner, .easy, .medium, .hard]
        default: Difficulty.allCases
        }
    }

    /// `difficulty` itself when offered, otherwise the closest offered tier by
    /// rank; a tie resolves to the easier side so a puzzle is never harder
    /// than its label.
    func nearestOfferedDifficulty(to difficulty: Difficulty) -> Difficulty {
        offeredDifficulties.min { lhs, rhs in
            let lhsDistance = abs(lhs.rank - difficulty.rank)
            let rhsDistance = abs(rhs.rank - difficulty.rank)
            return lhsDistance != rhsDistance ? lhsDistance < rhsDistance : lhs < rhs
        } ?? difficulty
    }
}
