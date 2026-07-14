/// What the player is entitled to, mapped out of RevenueCat into plain values.
public struct Entitlements: Equatable, Sendable, Codable {
    public enum Source: String, Equatable, Sendable, Codable {
        /// Raw values are persisted — they must never change.
        case notEntitled = "none"
        case subscription
        case lifetime
        case debugOverride = "debugOverride"
    }

    public let isPremium: Bool
    public let source: Source

    public static let free = Self(isPremium: false, source: .notEntitled)

    public init(isPremium: Bool, source: Source) {
        self.isPremium = isPremium
        self.source = source
    }
}
