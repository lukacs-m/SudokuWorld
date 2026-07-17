/// Selectable color themes. The palette definitions live in Presentation;
/// the identifier lives here so settings and entitlement gating stay in the
/// lower layers.
public enum ThemeID: String, CaseIterable, Equatable, Sendable, Codable {
    /// Raw values are persisted in settings — they must never change.
    case classicBlue = "classicBlue"
    case slate
    case forest
    case midnight
    case rose
    case amber

    /// Premium themes require the premium entitlement to select.
    public var isPremium: Bool {
        switch self {
        case .classicBlue, .slate, .forest: false
        case .midnight, .rose, .amber: true
        }
    }
}
