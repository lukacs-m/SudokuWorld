public import Model

/// The monetization abstraction. The production adapter wraps RevenueCat;
/// no SDK type ever crosses this boundary. When the API key is a placeholder
/// the adapter degrades to the free tier and `purchase`/`restore` throw
/// `DomainError.purchasesUnavailable`.
public protocol PurchasesService: Sendable {
    /// Safe to call unconditionally at launch; a no-op without a real key.
    func configure() async
    func entitlements() async -> Entitlements
    /// Emits on every entitlement change (purchase, restore, renewal, expiry).
    func entitlementUpdates() -> AsyncStream<Entitlements>
    func offerings() async throws -> PaywallOfferings
    func purchase(productID: String) async throws -> Entitlements
    func restore() async throws -> Entitlements
}

/// Product and entitlement identifiers shared between the adapter, the
/// paywall, and the README's store-setup instructions. These must match the
/// RevenueCat dashboard exactly: a purchase whose entitlement is named
/// differently succeeds in the store yet maps to the free tier.
public enum PremiumProducts {
    public static let entitlementID = "SudokuWorld Pro"
    public static let monthlySubscriptionID = "monthly"
    public static let yearlySubscriptionID = "yearly"
    public static let lifetimeID = "lifetime"
}
