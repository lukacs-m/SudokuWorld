import DI
import Domain
import Model
public import Observation

/// The single source of truth for premium: seeded from RevenueCat's cached
/// customer info (so it works offline), then kept live by the entitlement
/// stream (purchase, restore, renewal, expiry) and a foreground refresh.
/// Injected through the environment like `Router` and `ThemeStore`.
@MainActor
@Observable
public final class PremiumGate {
    public private(set) var isPremium: Bool

    @ObservationIgnored @Injected(\.getEntitlementsUseCase) private var getEntitlements
    @ObservationIgnored @Injected(\.observeEntitlementsUseCase) private var observeEntitlements

    /// The initial value is for previews and tests; launch overwrites it
    /// from the cache immediately.
    public init(isPremium: Bool = false) {
        self.isPremium = isPremium
    }

    /// Reads the cached state, then follows entitlement changes for the
    /// lifetime of the app. Call once at launch.
    public func start() async {
        await refresh()
        for await entitlements in observeEntitlements() {
            isPremium = entitlements.isPremium
        }
    }

    /// Re-reads entitlements; called when the app returns to the foreground.
    public func refresh() async {
        isPremium = await getEntitlements().isPremium
    }
}
