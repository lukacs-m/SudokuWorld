import Data
public import Domain
public import FactoryKit

/// Monetization wiring: purchases and entitlements.
public extension Container {
    var purchasesService: Factory<any PurchasesService> {
        self { RevenueCatPurchasesService() }
            .singleton
    }

    var configurePurchasesUseCase: Factory<any ConfigurePurchasesUseCase> {
        self { ConfigurePurchases(purchases: self.purchasesService()) }
    }

    var getEntitlementsUseCase: Factory<any GetEntitlementsUseCase> {
        self { GetEntitlements(purchases: self.purchasesService()) }
    }

    var observeEntitlementsUseCase: Factory<any ObserveEntitlementsUseCase> {
        self { ObserveEntitlements(purchases: self.purchasesService()) }
    }

    var getOfferingsUseCase: Factory<any GetOfferingsUseCase> {
        self { GetOfferings(purchases: self.purchasesService()) }
    }

    var purchasePremiumUseCase: Factory<any PurchasePremiumUseCase> {
        self { PurchasePremium(purchases: self.purchasesService()) }
    }

    var restorePurchasesUseCase: Factory<any RestorePurchasesUseCase> {
        self { RestorePurchases(purchases: self.purchasesService()) }
    }
}
