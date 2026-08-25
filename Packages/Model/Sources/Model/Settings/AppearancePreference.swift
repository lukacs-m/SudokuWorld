/// App-wide light/dark override; `system` follows the device.
public enum AppearancePreference: String, CaseIterable, Equatable, Sendable, Codable {
    case system
    case light
    case dark
}
