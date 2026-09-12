#if DEBUG
    public import Domain
    public import Model

    /// Decorator behind `LaunchHooks.forcePremium`: every entitlement read,
    /// update, purchase, and restore reports premium so screenshot runs can
    /// reach the subscriber branches without a sandbox purchase. Store
    /// configuration, offerings, and the user ID still go to the wrapped
    /// service.
    public struct DebugPremiumOverridePurchasesService: PurchasesService {
        private static let override = Entitlements(isPremium: true, source: .debugOverride)
        private let wrapped: any PurchasesService

        public init(wrapping wrapped: any PurchasesService) {
            self.wrapped = wrapped
        }

        public func configure() async {
            await wrapped.configure()
        }

        public func entitlements() -> Entitlements {
            Self.override
        }

        /// Maps rather than replaces the wrapped stream: an unconfigured SDK
        /// yields `.free` once, and that must not flip premium off.
        public func entitlementUpdates() -> AsyncStream<Entitlements> {
            let updates = wrapped.entitlementUpdates()
            return AsyncStream { continuation in
                continuation.yield(Self.override)
                let task = Task {
                    for await _ in updates {
                        continuation.yield(Self.override)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }

        public func offerings() async throws -> PaywallOfferings {
            try await wrapped.offerings()
        }

        public func purchase(productID _: String) -> Entitlements {
            Self.override
        }

        public func restore() -> Entitlements {
            Self.override
        }

        public func appUserID() async -> String? {
            await wrapped.appUserID()
        }
    }
#endif
