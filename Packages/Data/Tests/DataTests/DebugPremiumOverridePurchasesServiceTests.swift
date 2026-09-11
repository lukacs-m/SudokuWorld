#if DEBUG
    import Domain
    import Model
    import Testing
    @testable import Data

    @Suite
    struct DebugPremiumOverridePurchasesServiceTests {
        private let premium = Entitlements(isPremium: true, source: .debugOverride)

        @Test func entitlementsReportTheDebugOverride() {
            let service = DebugPremiumOverridePurchasesService(wrapping: FakePurchasesService())
            #expect(service.entitlements() == premium)
        }

        @Test func entitlementUpdatesMapFreeToPremium() async {
            let service = DebugPremiumOverridePurchasesService(wrapping: FakePurchasesService())
            var received: [Entitlements] = []
            for await entitlements in service.entitlementUpdates() {
                received.append(entitlements)
            }
            #expect(received.count == 1 + FakePurchasesService.wrappedUpdateCount)
            #expect(received.allSatisfy { $0 == premium })
        }

        @Test func restoreAndPurchaseSkipTheWrappedService() async {
            let fake = FakePurchasesService()
            let service = DebugPremiumOverridePurchasesService(wrapping: fake)
            #expect(service.restore() == premium)
            #expect(service.purchase(productID: "yearly") == premium)
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
        static let wrappedUpdateCount = 3
        static let offerings = PaywallOfferings(
            products: [
                PaywallProduct(
                    id: "fake-annual",
                    kind: .annual,
                    title: "Fake Annual",
                    details: "Only the wrapped service knows this product.",
                    priceText: "$0.00",
                ),
            ],
        )

        private var restoreCount = 0
        private var purchaseCount = 0

        func restoreCalls() -> Int { restoreCount }
        func purchaseCalls() -> Int { purchaseCount }

        func configure() {}

        func entitlements() -> Entitlements { .free }

        nonisolated func entitlementUpdates() -> AsyncStream<Entitlements> {
            AsyncStream { continuation in
                for _ in 0 ..< Self.wrappedUpdateCount {
                    continuation.yield(.free)
                }
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
