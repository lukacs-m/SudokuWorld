/// One reversible board mutation. Snapshots enough state that undo restores
/// the exact prior board — including pencil notes auto-cleaned from peers.
public struct Move: Equatable, Sendable, Codable {
    public let index: Int
    public let before: BoardCell
    public let after: BoardCell
    /// Peer notes wiped when this value was placed (auto-clean), keyed by
    /// cell index, holding each peer's notes as they were before the move.
    public let clearedPeerNotes: [Int: CellNotes]

    public init(
        index: Int,
        before: BoardCell,
        after: BoardCell,
        clearedPeerNotes: [Int: CellNotes] = [:],
    ) {
        self.index = index
        self.before = before
        self.after = after
        self.clearedPeerNotes = clearedPeerNotes
    }
}
