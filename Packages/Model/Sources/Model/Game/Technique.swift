/// Logical solving techniques the engine can find and explain, ordered by how
/// hard they are to spot. Grading derives a puzzle's difficulty from the
/// hardest technique its solution path requires.
public enum Technique: String, CaseIterable, Equatable, Sendable, Codable {
    /// Raw values feed the `hint.technique.*` localization keys — keep them
    /// stable so the string catalog stays aligned.
    case nakedSingle = "nakedSingle"
    case hiddenSingle = "hiddenSingle"
    case nakedPair = "nakedPair"
    case hiddenPair = "hiddenPair"
    case cageArithmetic = "cageArithmetic"
    case relationAnalysis = "relationAnalysis"
    case arrowArithmetic = "arrowArithmetic"
    case outsideClueAnalysis = "outsideClueAnalysis"
    case pointingPair = "pointingPair"
    case boxLineReduction = "boxLineReduction"
    case bentLine = "bentLine"
    case nakedTriple = "nakedTriple"
    case hiddenTriple = "hiddenTriple"
    case xWing = "xWing"
    case swordfish
    case xyWing = "xyWing"
    case xyChain = "xyChain"

    /// Monotonic spotting-difficulty rank used by the grader.
    public var rank: Int {
        switch self {
        case .nakedSingle: 0
        case .hiddenSingle: 1
        case .nakedPair: 2
        case .hiddenPair: 3
        case .cageArithmetic: 4
        // Reading a dot/inequality mark is the *basic* move of relation
        // variants — as easy as a hidden single — so it shares that rank;
        // otherwise no kropki could ever grade below medium. Ranks are
        // code-only and freely tunable — unlike slugs they never persist.
        case .relationAnalysis: 1
        // Arrow-sum bounding is cage-arithmetic-grade spotting work.
        case .arrowArithmetic: 4
        // Reasoning from edge clues shares the hard band with X-wing.
        case .outsideClueAnalysis: 9
        case .pointingPair: 5
        case .boxLineReduction: 6
        // Pointing across a fold is the same spotting work as a pointing pair.
        case .bentLine: 5
        case .nakedTriple: 7
        case .hiddenTriple: 8
        case .xWing: 9
        case .swordfish: 10
        case .xyWing: 11
        case .xyChain: 12
        }
    }
}
