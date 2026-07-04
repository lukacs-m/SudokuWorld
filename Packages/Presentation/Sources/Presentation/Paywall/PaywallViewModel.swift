public import Common
import DI
import Domain
import Foundation
public import Model
public import Observation

/// Paywall state: offerings, purchase/restore flows, and graceful handling
/// of the keyless (placeholder API key) configuration.
@MainActor
@Observable
public final class PaywallViewModel {
    public enum PurchasePhase: Equatable {
        case idle
        case purchasing
        case restored
        case purchased
        case failed(String)
    }

    public private(set) var state: ViewState<PaywallOfferings> = .idle
    public private(set) var purchasePhase: PurchasePhase = .idle
    public private(set) var isPremium = false

    @ObservationIgnored @Injected(\.getOfferingsUseCase) private var getOfferings
    @ObservationIgnored @Injected(\.purchasePremiumUseCase) private var purchasePremium
    @ObservationIgnored @Injected(\.restorePurchasesUseCase) private var restorePurchases
    @ObservationIgnored @Injected(\.getEntitlementsUseCase) private var getEntitlements

    public init() {}

    public func load() async {
        state = .loading
        isPremium = await getEntitlements().isPremium
        do {
            let offerings = try await getOfferings()
            state = offerings.products.isEmpty ? .empty : .loaded(offerings)
        } catch {
            state = .failed(String(localized: "paywall.unavailable", bundle: .module))
        }
    }

    public func purchase(productID: String) async {
        purchasePhase = .purchasing
        do {
            let entitlements = try await purchasePremium(productID: productID)
            isPremium = entitlements.isPremium
            purchasePhase = entitlements.isPremium ? .purchased : .idle
        } catch DomainError.purchaseCancelled {
            purchasePhase = .idle
        } catch {
            purchasePhase = .failed(String(localized: "paywall.purchaseFailed", bundle: .module))
        }
    }

    public func restore() async {
        purchasePhase = .purchasing
        do {
            let entitlements = try await restorePurchases()
            isPremium = entitlements.isPremium
            purchasePhase = entitlements.isPremium ? .restored : .failed(
                String(localized: "paywall.nothingToRestore", bundle: .module),
            )
        } catch {
            purchasePhase = .failed(String(localized: "paywall.restoreFailed", bundle: .module))
        }
    }
}
