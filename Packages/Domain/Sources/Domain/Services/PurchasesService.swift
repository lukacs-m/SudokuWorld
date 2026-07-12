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
/// paywall, and the README's store-setup instructions.
public enum PremiumProducts {
    public static let entitlementID = "premium"
    public static let yearlySubscriptionID = "sudokuworld.premium.yearly"
    public static let lifetimeID = "sudokuworld.premium.lifetime"
}

/// Free-tier limits lifted by premium.
public enum FreeTier {
    /// Logical hints allowed per game for free players.
    public static let hintsPerGame = 3
}
