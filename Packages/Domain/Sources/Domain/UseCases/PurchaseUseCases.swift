public import Model

/// Configures the purchases SDK at launch (no-op with a placeholder key).
public protocol ConfigurePurchasesUseCase: Sendable {
    func callAsFunction() async
}

public struct ConfigurePurchases: ConfigurePurchasesUseCase {
    private let purchases: any PurchasesService

    public init(purchases: any PurchasesService) {
        self.purchases = purchases
    }

    public func callAsFunction() async {
        await purchases.configure()
    }
}

/// Current entitlements snapshot.
public protocol GetEntitlementsUseCase: Sendable {
    func callAsFunction() async -> Entitlements
}

public struct GetEntitlements: GetEntitlementsUseCase {
    private let purchases: any PurchasesService

    public init(purchases: any PurchasesService) {
        self.purchases = purchases
    }

    public func callAsFunction() async -> Entitlements {
        await purchases.entitlements()
    }
}

/// Streams entitlement changes (purchases, renewals, restores, expiry).
public protocol ObserveEntitlementsUseCase: Sendable {
    func callAsFunction() -> AsyncStream<Entitlements>
}

public struct ObserveEntitlements: ObserveEntitlementsUseCase {
    private let purchases: any PurchasesService

    public init(purchases: any PurchasesService) {
        self.purchases = purchases
    }

    public func callAsFunction() -> AsyncStream<Entitlements> {
        purchases.entitlementUpdates()
    }
}

/// Loads the paywall's products.
public protocol GetOfferingsUseCase: Sendable {
    func callAsFunction() async throws -> PaywallOfferings
}

public struct GetOfferings: GetOfferingsUseCase {
    private let purchases: any PurchasesService

    public init(purchases: any PurchasesService) {
        self.purchases = purchases
    }

    public func callAsFunction() async throws -> PaywallOfferings {
        try await purchases.offerings()
    }
}

/// Runs a purchase to completion and returns the updated entitlements.
public protocol PurchasePremiumUseCase: Sendable {
    func callAsFunction(productID: String) async throws -> Entitlements
}

public struct PurchasePremium: PurchasePremiumUseCase {
    private let purchases: any PurchasesService

    public init(purchases: any PurchasesService) {
        self.purchases = purchases
    }

    public func callAsFunction(productID: String) async throws -> Entitlements {
        try await purchases.purchase(productID: productID)
    }
}

/// Restores prior purchases.
public protocol RestorePurchasesUseCase: Sendable {
    func callAsFunction() async throws -> Entitlements
}

public struct RestorePurchases: RestorePurchasesUseCase {
    private let purchases: any PurchasesService

    public init(purchases: any PurchasesService) {
        self.purchases = purchases
    }

    public func callAsFunction() async throws -> Entitlements {
        try await purchases.restore()
    }
}
