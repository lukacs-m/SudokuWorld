/// What kind of all-different unit a house is. Solving techniques use this to
/// reason structurally (pointing pairs need box→line, X-wing needs rows and
/// columns) without variant-specific code.
public enum HouseKind: String, Equatable, Sendable, Codable {
    case row
    case column
    case box
    case diagonal
    case window
}
