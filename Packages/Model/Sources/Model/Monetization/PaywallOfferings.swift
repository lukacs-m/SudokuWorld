/// Purchasable products for the paywall, mapped out of RevenueCat offerings.
public struct PaywallOfferings: Equatable, Sendable {
    public let products: [PaywallProduct]

    public static let empty = PaywallOfferings(products: [])

    public init(products: [PaywallProduct]) {
        self.products = products
    }
}

public struct PaywallProduct: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// An auto-renewing subscription with a localized period description.
        case subscription(period: String)
        /// The one-time lifetime unlock.
        case lifetime
    }

    /// Store product identifier, e.g. "sudokuworld.premium.yearly".
    public let id: String
    public let kind: Kind
    public let title: String
    public let details: String
    /// Localized price straight from StoreKit.
    public let priceText: String

    public init(id: String, kind: Kind, title: String, details: String, priceText: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.details = details
        self.priceText = priceText
    }
}
