/// Rule set for a single game. Hardcore limits mistakes and disables hints;
/// exceeding the limit is the only way a game counts as lost.
public enum GameMode: String, CaseIterable, Equatable, Sendable, Codable {
    case normal
    case hardcore

    /// Mistakes allowed before the game is lost; nil means unlimited.
    public var maxMistakes: Int? {
        switch self {
        case .normal: nil
        case .hardcore: 3
        }
    }

    public var allowsHints: Bool {
        switch self {
        case .normal: true
        case .hardcore: false
        }
    }
}
