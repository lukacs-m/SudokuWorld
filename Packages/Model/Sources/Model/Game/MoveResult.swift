/// What a board mutation amounted to, so the UI can react (haptics, mistake
/// counter, celebration) without re-deriving game state.
public enum MoveResult: Equatable, Sendable {
    /// A valid entry (or note/clear edit) was applied.
    case placed
    /// A wrong digit was placed; carries the updated mistake total.
    case mistake(total: Int)
    /// The placement completed the puzzle correctly.
    case solved
    /// The mistake limit was exceeded in hardcore mode — the game is lost.
    case hardcoreLoss
    /// Nothing changed (given cell, identical value, or game already over).
    case rejected
}
