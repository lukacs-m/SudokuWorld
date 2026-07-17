/// How taps map to entries: select a cell then a digit, or arm a digit and
/// paint it into cells.
public enum InputMode: String, CaseIterable, Equatable, Sendable, Codable {
    /// Raw values are persisted in settings — they must never change.
    case cellFirst = "cellFirst"
    case digitFirst = "digitFirst"
}
