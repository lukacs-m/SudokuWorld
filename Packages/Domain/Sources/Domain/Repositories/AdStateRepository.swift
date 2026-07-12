public import Foundation

/// Counters behind the interstitial frequency policy.
public protocol AdStateRepository: Sendable {
    func gamesFinishedSinceInterstitial() async -> Int
    func recordGameFinished() async
    func recordInterstitialShown(at date: Date) async
    func lastInterstitialShownAt() async -> Date?
}
