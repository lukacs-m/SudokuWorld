public import Domain
public import Foundation

/// UserDefaults-backed counters behind the interstitial frequency policy.
public actor UserDefaultsAdStateRepository: AdStateRepository {
    private enum Keys {
        static let gamesFinished = "ads.gamesFinishedSinceInterstitial"
        static let lastShownAt = "ads.lastInterstitialShownAt"
    }

    private let defaults: UserDefaults

    public init(suiteName: String? = nil) {
        defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    public func gamesFinishedSinceInterstitial() -> Int {
        defaults.integer(forKey: Keys.gamesFinished)
    }

    public func recordGameFinished() {
        let current = defaults.integer(forKey: Keys.gamesFinished)
        defaults.set(current + 1, forKey: Keys.gamesFinished)
    }

    public func recordInterstitialShown(at date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: Keys.lastShownAt)
        defaults.set(0, forKey: Keys.gamesFinished)
    }

    public func lastInterstitialShownAt() -> Date? {
        let stored = defaults.double(forKey: Keys.lastShownAt)
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }
}
