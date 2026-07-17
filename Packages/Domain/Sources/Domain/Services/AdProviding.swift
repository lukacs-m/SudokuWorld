public import Foundation
public import Model

/// Ad inventory abstraction. The shipped implementation serves house
/// creatives; a real network adapter (AdMob) maps its payloads into the same
/// `AdCreative` values — see the README for the drop-in guide.
public protocol AdProviding: Sendable {
    func banner(for placement: AdPlacement) async -> AdCreative?
    func interstitial() async -> AdCreative?
}

/// When interstitials may appear: only between games, never more often than
/// every `gamesBetweenInterstitials` finished games, with a wall-clock
/// cooldown on top. Pure and unit-tested; premium is checked upstream.
public struct InterstitialPolicy: Equatable, Sendable {
    public let gamesBetweenInterstitials: Int
    public let cooldownSeconds: TimeInterval

    public static let standard = Self(
        gamesBetweenInterstitials: 3,
        cooldownSeconds: 180,
    )

    public init(gamesBetweenInterstitials: Int, cooldownSeconds: TimeInterval) {
        self.gamesBetweenInterstitials = gamesBetweenInterstitials
        self.cooldownSeconds = cooldownSeconds
    }

    public func allowsInterstitial(
        gamesFinishedSince: Int,
        lastShownAt: Date?,
        now: Date,
    ) -> Bool {
        guard gamesFinishedSince >= gamesBetweenInterstitials else { return false }
        if let lastShownAt, now.timeIntervalSince(lastShownAt) < cooldownSeconds {
            return false
        }
        return true
    }
}
