import Common
public import Domain
import Foundation
public import Model
import RevenueCat

/// RevenueCat adapter. No SDK type crosses this boundary (all imports stay
/// internal); with a placeholder API key the adapter degrades gracefully —
/// `configure()` no-ops, entitlements report the free tier, and purchase
/// flows throw `DomainError.purchasesUnavailable` so the paywall can explain.
public struct RevenueCatPurchasesService: PurchasesService {
    public init() {}

    public func configure() {
        guard !AppSecrets.revenueCatKeyIsPlaceholder else {
            Log.info("RevenueCat: placeholder API key — purchases disabled")
            return
        }
        guard !Purchases.isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppSecrets.revenueCatAPIKey)
    }

    public func entitlements() async -> Entitlements {
        guard Purchases.isConfigured else { return .free }
        do {
            return try await Self.map(Purchases.shared.customerInfo())
        } catch {
            Log.error("RevenueCat customerInfo failed: \(error)")
            return .free
        }
    }

    public func entitlementUpdates() -> AsyncStream<Entitlements> {
        AsyncStream { continuation in
            guard Purchases.isConfigured else {
                continuation.yield(.free)
                continuation.finish()
                return
            }
            let task = Task {
                for await info in Purchases.shared.customerInfoStream {
                    continuation.yield(Self.map(info))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func offerings() async throws -> PaywallOfferings {
        guard Purchases.isConfigured else { throw DomainError.purchasesUnavailable }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { return .empty }
            return PaywallOfferings(
                products: current.availablePackages
                    .compactMap(Self.map(package:))
                    .sorted { Self.displayRank($0.kind) < Self.displayRank($1.kind) },
            )
        } catch {
            throw DomainError.purchasesUnavailable
        }
    }

    public func purchase(productID: String) async throws -> Entitlements {
        guard Purchases.isConfigured else { throw DomainError.purchasesUnavailable }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages
                .first(where: { $0.storeProduct.productIdentifier == productID })
            else { throw DomainError.notFound }

            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                throw DomainError.purchaseCancelled
            }
            return Self.map(result.customerInfo)
        } catch let error as DomainError {
            throw error
        } catch {
            if let purchasesError = error as? RevenueCat.ErrorCode,
               purchasesError == .purchaseCancelledError
            {
                throw DomainError.purchaseCancelled
            }
            Log.error("Purchase failed: \(error)")
            throw DomainError.purchasesUnavailable
        }
    }

    public func restore() async throws -> Entitlements {
        guard Purchases.isConfigured else { throw DomainError.purchasesUnavailable }
        do {
            return try await Self.map(Purchases.shared.restorePurchases())
        } catch {
            Log.error("Restore failed: \(error)")
            throw DomainError.purchasesUnavailable
        }
    }

    // MARK: - Mapping

    private static func map(_ info: CustomerInfo) -> Entitlements {
        guard let entitlement = info.entitlements[PremiumProducts.entitlementID],
              entitlement.isActive
        else { return .free }
        let source: Entitlements.Source = entitlement.productIdentifier == PremiumProducts
            .lifetimeID
            ? .lifetime
            : .subscription
        return Entitlements(isPremium: true, source: source)
    }

    /// Maps by package type — the offering is the source of truth for which
    /// three products exist; anything else in it is ignored.
    private static func map(package: Package) -> PaywallProduct? {
        let kind: PaywallProduct.Kind? = switch package.packageType {
        case .monthly: .monthly
        case .annual: .annual
        case .lifetime: .lifetime
        default: nil
        }
        guard let kind else { return nil }
        let product = package.storeProduct
        return PaywallProduct(
            id: product.productIdentifier,
            kind: kind,
            title: product.localizedTitle,
            details: product.localizedDescription,
            priceText: product.localizedPriceString,
            trialDays: Self.trialDays(product.introductoryDiscount),
        )
    }

    private static func trialDays(_ intro: StoreProductDiscount?) -> Int? {
        guard let intro, intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        return switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        }
    }

    private static func displayRank(_ kind: PaywallProduct.Kind) -> Int {
        switch kind {
        case .monthly: 0
        case .annual: 1
        case .lifetime: 2
        }
    }
}
