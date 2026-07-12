public import Domain
import Foundation
public import Model

/// The shipped ad inventory: first-party "house" creatives promoting Premium
/// and the daily challenge, with simulated network latency. Text fields hold
/// string-catalog keys that Presentation resolves, so house ads localize like
/// everything else. Swap for a real network adapter (AdMob) by re-registering
/// `Container.adProvider` — see the README's drop-in guide.
public struct SimulatedAdProvider: AdProviding {
    private static let banners: [AdCreative] = [
        AdCreative(
            id: "house.premium.banner",
            format: .banner,
            headline: "ad.house.premium.headline",
            body: "ad.house.premium.body",
            callToAction: "ad.house.premium.cta",
        ),
        AdCreative(
            id: "house.daily.banner",
            format: .banner,
            headline: "ad.house.daily.headline",
            body: "ad.house.daily.body",
            callToAction: "ad.house.daily.cta",
        ),
        AdCreative(
            id: "house.hardcore.banner",
            format: .banner,
            headline: "ad.house.hardcore.headline",
            body: "ad.house.hardcore.body",
            callToAction: "ad.house.hardcore.cta",
        ),
    ]

    private static let interstitials: [AdCreative] = [
        AdCreative(
            id: "house.premium.interstitial",
            format: .interstitial,
            headline: "ad.house.premium.headline",
            body: "ad.house.premium.body",
            callToAction: "ad.house.premium.cta",
            minimumDisplaySeconds: 3,
        ),
        AdCreative(
            id: "house.variety.interstitial",
            format: .interstitial,
            headline: "ad.house.variety.headline",
            body: "ad.house.variety.body",
            callToAction: "ad.house.variety.cta",
            minimumDisplaySeconds: 3,
        ),
    ]

    public init() {}

    public func banner(for placement: AdPlacement) async -> AdCreative? {
        guard placement != .betweenGames else { return nil }
        try? await Task.sleep(for: .milliseconds(150))
        return Self.banners[rotationIndex(count: Self.banners.count, salt: placement.rawValue)]
    }

    public func interstitial() async -> AdCreative? {
        try? await Task.sleep(for: .milliseconds(250))
        return Self.interstitials[rotationIndex(count: Self.interstitials.count, salt: "i")]
    }

    /// Rotates creatives every few minutes, deterministically per slot.
    private func rotationIndex(count: Int, salt: String) -> Int {
        let window = Int(Date().timeIntervalSince1970 / 300)
        return abs((window &+ salt.utf8.count) % count)
    }
}
