import Domain
import Foundation
import Model
import RevenueCat
import Testing
@testable import Data

/// Pins the entitlement/product identifiers against what the RevenueCat
/// dashboard actually returns (observed on the test store, 2026-09-04): the
/// entitlement is "SudokuWorld Pro" and the products are "monthly",
/// "yearly", "lifetime". A drift here makes purchases succeed while the app
/// stays free.
@Suite
struct RevenueCatPurchasesServiceTests {
    private func customerInfo(entitlements: [EntitlementInfo]) -> CustomerInfo {
        CustomerInfo(
            entitlements: EntitlementInfos(
                entitlements: Dictionary(uniqueKeysWithValues: entitlements.map { ($0.identifier, $0) }),
            ),
            requestDate: Date(),
            firstSeen: Date(),
            originalAppUserId: "$RCAnonymousID:test",
        )
    }

    private func entitlement(
        _ identifier: String,
        product: String,
        isActive: Bool = true,
    ) -> EntitlementInfo {
        EntitlementInfo(
            identifier: identifier,
            isActive: isActive,
            willRenew: isActive,
            periodType: .normal,
            store: .appStore,
            productIdentifier: product,
            isSandbox: true,
            ownershipType: .purchased,
        )
    }

    @Test func dashboardEntitlementWithSubscriptionIsPremium() {
        let info = customerInfo(entitlements: [entitlement("SudokuWorld Pro", product: "yearly")])
        #expect(RevenueCatPurchasesService.map(info) == Entitlements(isPremium: true, source: .subscription))
    }

    @Test func dashboardEntitlementWithLifetimeProductIsLifetime() {
        let info = customerInfo(entitlements: [entitlement("SudokuWorld Pro", product: "lifetime")])
        #expect(RevenueCatPurchasesService.map(info) == Entitlements(isPremium: true, source: .lifetime))
    }

    /// The pre-fix identifier: an active entitlement under any other name is
    /// invisible to the app, which is exactly the bug this suite guards.
    @Test func differentlyNamedEntitlementIsFree() {
        let info = customerInfo(entitlements: [entitlement("premium", product: "yearly")])
        #expect(RevenueCatPurchasesService.map(info) == .free)
    }

    @Test func inactiveEntitlementIsFree() {
        let info = customerInfo(entitlements: [
            entitlement("SudokuWorld Pro", product: "monthly", isActive: false),
        ])
        #expect(RevenueCatPurchasesService.map(info) == .free)
    }

    @Test func noEntitlementsIsFree() {
        #expect(RevenueCatPurchasesService.map(customerInfo(entitlements: [])) == .free)
    }
}
