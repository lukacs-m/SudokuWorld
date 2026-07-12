public import Foundation
public import Model

/// The one gate every interstitial passes through. Called exactly once per
/// finished game, from the game-exit flow — never mid-puzzle. Premium
/// entitlement short-circuits everything.
public protocol InterstitialGateUseCase: Sendable {
    func callAsFunction(at now: Date) async -> AdCreative?
}

public struct InterstitialGate: InterstitialGateUseCase {
    private let purchases: any PurchasesService
    private let adState: any AdStateRepository
    private let adProvider: any AdProviding
    private let policy: InterstitialPolicy

    public init(
        purchases: any PurchasesService,
        adState: any AdStateRepository,
        adProvider: any AdProviding,
        policy: InterstitialPolicy = .standard,
    ) {
        self.purchases = purchases
        self.adState = adState
        self.adProvider = adProvider
        self.policy = policy
    }

    public func callAsFunction(at now: Date) async -> AdCreative? {
        await adState.recordGameFinished()

        guard await !purchases.entitlements().isPremium else { return nil }

        let gamesSince = await adState.gamesFinishedSinceInterstitial()
        let lastShown = await adState.lastInterstitialShownAt()
        guard policy.allowsInterstitial(
            gamesFinishedSince: gamesSince,
            lastShownAt: lastShown,
            now: now,
        ) else { return nil }

        guard let creative = await adProvider.interstitial() else { return nil }
        await adState.recordInterstitialShown(at: now)
        return creative
    }
}

/// Banner inventory for non-game screens; empty for premium players.
public protocol GetBannerUseCase: Sendable {
    func callAsFunction(placement: AdPlacement) async -> AdCreative?
}

public struct GetBanner: GetBannerUseCase {
    private let purchases: any PurchasesService
    private let adProvider: any AdProviding

    public init(purchases: any PurchasesService, adProvider: any AdProviding) {
        self.purchases = purchases
        self.adProvider = adProvider
    }

    public func callAsFunction(placement: AdPlacement) async -> AdCreative? {
        guard placement != .betweenGames else { return nil }
        guard await !purchases.entitlements().isPremium else { return nil }
        return await adProvider.banner(for: placement)
    }
}
