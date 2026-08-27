import DI
import FactoryTesting
import Model
import Testing
@testable import Presentation

@Suite(.container)
@MainActor
struct PremiumGateTests {
    private func registerMocks(
        entitlements: Entitlements = .free,
        updates: [Entitlements] = [],
    ) {
        Container.shared.getEntitlementsUseCase.register {
            MockGetEntitlements(entitlements: entitlements)
        }
        Container.shared.observeEntitlementsUseCase.register {
            MockObserveEntitlements(values: updates)
        }
    }

    @Test func startsFreeForFreeTier() async {
        registerMocks()
        let gate = PremiumGate()
        await gate.start()
        #expect(!gate.isPremium)
    }

    @Test func cachedEntitlementSeedsPremium() async {
        registerMocks(entitlements: Entitlements(isPremium: true, source: .subscription))
        let gate = PremiumGate()
        await gate.refresh()
        #expect(gate.isPremium)
    }

    @Test func streamedPurchaseFlipsPremium() async {
        registerMocks(updates: [Entitlements(isPremium: true, source: .lifetime)])
        let gate = PremiumGate()
        await gate.start()
        #expect(gate.isPremium)
    }

    @Test func streamedExpiryRevokesPremium() async {
        registerMocks(
            entitlements: Entitlements(isPremium: true, source: .subscription),
            updates: [.free],
        )
        let gate = PremiumGate()
        await gate.start()
        #expect(!gate.isPremium)
    }
}
