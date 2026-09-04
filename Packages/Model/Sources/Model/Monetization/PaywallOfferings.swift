/// Purchasable products for the paywall, mapped out of RevenueCat offerings.
public struct PaywallOfferings: Equatable, Sendable {
    public let products: [PaywallProduct]

    public static let empty = Self(products: [])

    public init(products: [PaywallProduct]) {
        self.products = products
    }
}

public struct PaywallProduct: Identifiable, Equatable, Sendable {
    /// Mirrors the RevenueCat offering's package types; the paywall shows
    /// exactly these three, with annual anchored as best value.
    public enum Kind: Equatable, Sendable {
        case monthly
        case annual
        /// The one-time lifetime unlock.
        case lifetime
    }

    /// Store product identifier, e.g. "yearly".
    public let id: String
    public let kind: Kind
    public let title: String
    public let details: String
    /// Localized price straight from StoreKit.
    public let priceText: String
    /// Length of the free introductory trial in days, nil without one.
    public let trialDays: Int?

    public init(
        id: String,
        kind: Kind,
        title: String,
        details: String,
        priceText: String,
        trialDays: Int? = nil,
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.details = details
        self.priceText = priceText
        self.trialDays = trialDays
    }
}
