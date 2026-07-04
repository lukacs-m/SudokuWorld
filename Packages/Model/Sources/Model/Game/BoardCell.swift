/// One cell of a live board: either a fixed given or a player-editable cell
/// carrying an optional value and pencil notes.
public struct BoardCell: Equatable, Sendable, Codable {
    public var value: Int?
    public let isGiven: Bool
    public var notes: CellNotes

    public init(value: Int? = nil, isGiven: Bool = false, notes: CellNotes = CellNotes()) {
        self.value = value
        self.isGiven = isGiven
        self.notes = notes
    }
}
