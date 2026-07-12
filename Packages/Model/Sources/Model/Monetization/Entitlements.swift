/// What the player is entitled to, mapped out of RevenueCat into plain values.
public struct Entitlements: Equatable, Sendable, Codable {
    public enum Source: String, Equatable, Sendable, Codable {
        case none
        case subscription
        case lifetime
        case debugOverride
    }

    public let isPremium: Bool
    public let source: Source

    public static let free = Entitlements(isPremium: false, source: .none)

    public init(isPremium: Bool, source: Source) {
        self.isPremium = isPremium
        self.source = source
    }
}
