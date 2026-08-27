import Common
import DI
import Domain
import FactoryTesting
import Foundation
import Model
import Testing
@testable import Presentation

@Suite(.container)
@MainActor
struct HomeViewModelTests {
    private func registerMocks(saved: SavedGame? = nil) {
        Container.shared.resumeGameUseCase.register { MockResumeGame(saved: saved) }
        Container.shared.computeStatsUseCase.register { MockComputeStats() }
        Container.shared.getDailyLineupUseCase.register { MockGetDailyLineup() }
    }

    @Test func refreshLoadsContentAndDaily() async {
        registerMocks()
        let viewModel = HomeViewModel()
        await viewModel.refresh()

        #expect(viewModel.state.value != nil)
        #expect(viewModel.state.value?.continueGame == nil)
        #expect(viewModel.dailyState.value != nil)
        #expect(viewModel.dailyState.value?.slots.allSatisfy { !$0.isCompleted } == true)
    }

    @Test func continueCardAppearsWithASavedGame() async {
        let session = TestFixtures.session()
        registerMocks(saved: session.savedGame(at: Date()))
        let viewModel = HomeViewModel()
        await viewModel.refresh()

        #expect(viewModel.state.value?.continueGame != nil)
        #expect(viewModel.state.value?.continueGame?.puzzle.variant == .classic)
    }

}

@Suite(.container)
@MainActor
struct StatsViewModelTests {
    @Test func emptyHistoryShowsEmptyState() async {
        Container.shared.computeStatsUseCase.register { MockComputeStats(overview: .empty) }

        let viewModel = StatsViewModel()
        await viewModel.load()
        if case .empty = viewModel.state {} else {
            Issue.record("Expected .empty, got \(viewModel.state)")
        }
    }

    @Test func historyLoadsOverview() async {
        let overview = StatsOverview(
            totalPlayed: 5,
            totalWon: 3,
            totalLost: 1,
            totalAbandoned: 1,
            streaks: .zero,
            perVariant: [],
            gamesPerDay: [],
            winRateByDifficulty: [],
            timesByDifficulty: [],
            variantShares: [],
        )
        Container.shared.computeStatsUseCase.register { MockComputeStats(overview: overview) }

        let viewModel = StatsViewModel()
        await viewModel.load()
        #expect(viewModel.state.value?.totalPlayed == 5)
        #expect(viewModel.state.value?.winRate == 0.6)
    }
}

@Suite(.container)
@MainActor
struct EventsHubViewModelTests {
    private func registerMocks(auth: GameCenterAuthState = .unauthenticated) {
        Container.shared.getDailyLineupUseCase.register { MockGetDailyLineup() }
        Container.shared.getWeeklyTournamentUseCase.register { MockGetWeeklyTournament() }
        Container.shared.getStandingsUseCase.register { MockGetStandings() }
        Container.shared.observeGameCenterAuthUseCase.register {
            MockObserveGameCenterAuth(state: auth)
        }
    }

    @Test func loadPopulatesBothEvents() async {
        registerMocks()
        let viewModel = EventsHubViewModel()
        await viewModel.load()

        #expect(viewModel.state.value?.daily.slots.count == 3)
        #expect(viewModel.state.value?.weekly.points == 1500)
        #expect(viewModel.state.value?.weekly.variant == .killer)
    }

    @Test func standingsStayIdleWithoutAuthentication() async {
        registerMocks(auth: .unauthenticated)
        let viewModel = EventsHubViewModel()
        await viewModel.load()

        if case .idle = viewModel.dailyStandings {} else {
            Issue.record("Expected idle standings, got \(viewModel.dailyStandings)")
        }
    }
}

@Suite(.container)
@MainActor
struct PaywallViewModelTests {
    private func registerMocks(
        offerings: Result<PaywallOfferings, DomainError> = .success(.empty),
        purchase: Result<Entitlements, DomainError> =
            .success(Entitlements(isPremium: true, source: .subscription)),
        restore: Result<Entitlements, DomainError> = .success(.free),
    ) {
        Container.shared.getOfferingsUseCase.register { MockGetOfferings(result: offerings) }
        Container.shared.purchasePremiumUseCase.register { MockPurchasePremium(result: purchase) }
        Container.shared.restorePurchasesUseCase.register { MockRestorePurchases(result: restore) }
        Container.shared.getEntitlementsUseCase.register { MockGetEntitlements() }
    }

    private var sampleOfferings: PaywallOfferings {
        PaywallOfferings(products: [
            PaywallProduct(
                id: PremiumProducts.monthlySubscriptionID,
                kind: .monthly,
                title: "Premium Monthly",
                details: "All the things",
                priceText: "$2.99",
            ),
            PaywallProduct(
                id: PremiumProducts.yearlySubscriptionID,
                kind: .annual,
                title: "Premium",
                details: "All the things",
                priceText: "$19.99",
                trialDays: 7,
            ),
            PaywallProduct(
                id: PremiumProducts.lifetimeID,
                kind: .lifetime,
                title: "Lifetime",
                details: "Forever",
                priceText: "$49.99",
            ),
        ])
    }

    @Test func offeringsLoad() async {
        registerMocks(offerings: .success(sampleOfferings))
        let viewModel = PaywallViewModel()
        await viewModel.load()
        #expect(viewModel.state.value?.products.count == 3)
    }

    @Test func keylessConfigurationShowsUnavailable() async {
        registerMocks(offerings: .failure(.purchasesUnavailable))
        let viewModel = PaywallViewModel()
        await viewModel.load()
        if case .failed = viewModel.state {} else {
            Issue.record("Expected .failed, got \(viewModel.state)")
        }
    }

    @Test func purchaseFlipsPremium() async {
        registerMocks(offerings: .success(sampleOfferings))
        let viewModel = PaywallViewModel()
        await viewModel.load()
        await viewModel.purchase(productID: PremiumProducts.yearlySubscriptionID)

        #expect(viewModel.isPremium)
        #expect(viewModel.purchasePhase == .purchased)
    }

    @Test func cancelledPurchaseReturnsToIdle() async {
        registerMocks(
            offerings: .success(sampleOfferings),
            purchase: .failure(.purchaseCancelled),
        )
        let viewModel = PaywallViewModel()
        await viewModel.load()
        await viewModel.purchase(productID: PremiumProducts.yearlySubscriptionID)

        #expect(!viewModel.isPremium)
        #expect(viewModel.purchasePhase == .idle)
    }

    @Test func restoreWithoutPurchasesReportsNothing() async {
        registerMocks(restore: .success(.free))
        let viewModel = PaywallViewModel()
        await viewModel.restore()

        if case .failed = viewModel.purchasePhase {} else {
            Issue.record("Expected .failed phase, got \(viewModel.purchasePhase)")
        }
    }
}

@Suite(.container)
@MainActor
struct SettingsViewModelTests {
    private func registerMocks() {
        Container.shared.settingsRepository.register { MockSettingsRepository() }
        Container.shared.updateRemindersUseCase.register { MockUpdateReminders() }
        Container.shared.observeGameCenterAuthUseCase.register { MockObserveGameCenterAuth() }
        Container.shared.authenticateGameCenterUseCase.register { MockAuthenticateGameCenter() }
    }

    @Test func freeThemeSelectsDirectly() async {
        registerMocks()
        let viewModel = SettingsViewModel()
        await viewModel.load()

        #expect(viewModel.selectTheme(.forest, isPremium: false))
        #expect(viewModel.settings.theme == .forest)
    }

    @Test func premiumThemeIsGatedForFreeTier() async {
        registerMocks()
        let viewModel = SettingsViewModel()
        await viewModel.load()

        #expect(!viewModel.selectTheme(.midnight, isPremium: false))
        #expect(viewModel.settings.theme == .warmPaper)
    }

    @Test func premiumThemeUnlocksWithEntitlement() async {
        registerMocks()
        let viewModel = SettingsViewModel()
        await viewModel.load()

        #expect(viewModel.selectTheme(.midnight, isPremium: true))
        #expect(viewModel.settings.theme == .midnight)
    }

    @Test func settingsPersistThroughTheRepository() async {
        registerMocks()
        let viewModel = SettingsViewModel()
        await viewModel.load()

        viewModel.update { $0.autoCheck = true }
        #expect(viewModel.settings.autoCheck)
    }

    @Test func notificationDenialIsSurfaced() async {
        registerMocks()
        Container.shared.updateRemindersUseCase.register {
            MockUpdateReminders(authorized: false)
        }
        let viewModel = SettingsViewModel()
        await viewModel.load()

        await viewModel.updateNotifications { $0.dailyReminderEnabled = true }
        #expect(viewModel.notificationsDenied)
    }

    @Test func restoreRecoversPremium() async {
        registerMocks()
        Container.shared.restorePurchasesUseCase.register {
            MockRestorePurchases(result: .success(
                Entitlements(isPremium: true, source: .subscription),
            ))
        }
        let viewModel = SettingsViewModel()

        await viewModel.restore()
        #expect(viewModel.restorePhase == .restored)
    }

    @Test func restoreWithNoPurchasesSaysSo() async {
        registerMocks()
        Container.shared.restorePurchasesUseCase.register {
            MockRestorePurchases(result: .success(.free))
        }
        let viewModel = SettingsViewModel()

        await viewModel.restore()
        #expect(viewModel.restorePhase == .nothingToRestore)
    }

    @Test func restoreFailureIsSurfaced() async {
        registerMocks()
        Container.shared.restorePurchasesUseCase.register {
            MockRestorePurchases(result: .failure(.purchasesUnavailable))
        }
        let viewModel = SettingsViewModel()

        await viewModel.restore()
        #expect(viewModel.restorePhase == .failed)
    }
}
