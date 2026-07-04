/// Logical solving techniques the engine can find and explain, ordered by how
/// hard they are to spot. Grading derives a puzzle's difficulty from the
/// hardest technique its solution path requires.
public enum Technique: String, CaseIterable, Equatable, Sendable, Codable {
    case nakedSingle
    case hiddenSingle
    case nakedPair
    case hiddenPair
    case cageArithmetic
    case pointingPair
    case boxLineReduction
    case nakedTriple
    case hiddenTriple
    case xWing

    /// Monotonic spotting-difficulty rank used by the grader.
    public var rank: Int {
        switch self {
        case .nakedSingle: 0
        case .hiddenSingle: 1
        case .nakedPair: 2
        case .hiddenPair: 3
        case .cageArithmetic: 4
        case .pointingPair: 5
        case .boxLineReduction: 6
        case .nakedTriple: 7
        case .hiddenTriple: 8
        case .xWing: 9
        }
    }
}
