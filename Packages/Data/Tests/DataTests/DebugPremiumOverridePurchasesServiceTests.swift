#if DEBUG
    import Domain
    import Model
    import Testing
    @testable import Data

    @Suite
    struct DebugPremiumOverridePurchasesServiceTests {
        private let premium = Entitlements(isPremium: true, source: .debugOverride)

        @Test func entitlementsReportTheDebugOverride() async {
            let service = DebugPremiumOverridePurchasesService(wrapping: FakePurchasesService())
            #expect(await service.entitlements() == premium)
        }

        @Test func entitlementUpdatesMapFreeToPremium() async {
            let service = DebugPremiumOverridePurchasesService(wrapping: FakePurchasesService())
            var received: [Entitlements] = []
            for await entitlements in service.entitlementUpdates() {
                received.append(entitlements)
            }
            #expect(!received.isEmpty)
            #expect(received.allSatisfy { $0 == premium })
        }

        @Test func restoreAndPurchaseSkipTheWrappedService() async throws {
            let fake = FakePurchasesService()
            let service = DebugPremiumOverridePurchasesService(wrapping: fake)
            #expect(try await service.restore() == premium)
            #expect(try await service.purchase(productID: "yearly") == premium)
            #expect(await fake.restoreCalls() == 0)
            #expect(await fake.purchaseCalls() == 0)
        }

        @Test func offeringsAndUserIDPassThrough() async throws {
            let fake = FakePurchasesService()
            let service = DebugPremiumOverridePurchasesService(wrapping: fake)
            #expect(try await service.offerings() == FakePurchasesService.offerings)
            #expect(await service.appUserID() == FakePurchasesService.userID)
        }
    }

    private actor FakePurchasesService: PurchasesService {
        static let userID = "fake-user"
        static let offerings = PaywallOfferings(products: [])

        private var restoreCount = 0
        private var purchaseCount = 0

        func restoreCalls() -> Int { restoreCount }
        func purchaseCalls() -> Int { purchaseCount }

        func configure() {}

        func entitlements() -> Entitlements { .free }

        nonisolated func entitlementUpdates() -> AsyncStream<Entitlements> {
            AsyncStream { continuation in
                continuation.yield(.free)
                continuation.finish()
            }
        }

        func offerings() throws -> PaywallOfferings { Self.offerings }

        func purchase(productID _: String) throws -> Entitlements {
            purchaseCount += 1
            return .free
        }

        func restore() throws -> Entitlements {
            restoreCount += 1
            return .free
        }

        func appUserID() -> String? { Self.userID }
    }
#endif
