/// How a finished game ended. Losing is reserved for hardcore games that ran
/// out of mistakes; quitting mid-game records an abandonment.
public enum GameOutcome: String, CaseIterable, Equatable, Sendable, Codable {
    case won
    case lost
    case abandoned
}
