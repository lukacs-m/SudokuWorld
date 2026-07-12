public import Common
import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Home screen state: the resumable game, streaks, today's challenge, and
/// the banner slot. The daily puzzle is cached per date key — it only
/// regenerates when the day rolls over or completion status may have changed.
@MainActor
@Observable
public final class HomeViewModel {
    public struct Content: Equatable, Sendable {
        public let continueGame: SavedGame?
        public let streaks: StreakInfo

        public init(continueGame: SavedGame?, streaks: StreakInfo) {
            self.continueGame = continueGame
            self.streaks = streaks
        }
    }

    public private(set) var state: ViewState<Content> = .idle
    public private(set) var dailyState: ViewState<DailyChallenge> = .idle
    public private(set) var banner: AdCreative?
    public private(set) var isPremium = false

    @ObservationIgnored @Injected(\.resumeGameUseCase) private var resumeGame
    @ObservationIgnored @Injected(\.computeStatsUseCase) private var computeStats
    @ObservationIgnored @Injected(\.getDailyChallengeUseCase) private var getDailyChallenge
    @ObservationIgnored @Injected(\.getBannerUseCase) private var getBanner
    @ObservationIgnored @Injected(\.getEntitlementsUseCase) private var getEntitlements

    public init() {}

    /// Refreshes everything; cheap parts land first, the daily follows.
    public func refresh(now: Date = Date()) async {
        if case .idle = state {
            state = .loading
        }
        let session = await resumeGame(context: .regular)
        let stats = await computeStats(today: now)
        state = .loaded(Content(
            continueGame: session?.savedGame(at: now),
            streaks: stats.streaks,
        ))

        isPremium = await getEntitlements().isPremium
        banner = isPremium ? nil : await getBanner(placement: .homeBanner)

        await refreshDaily(now: now)
    }

    private func refreshDaily(now: Date) async {
        let todayKey = EventSeeds.dailyDateKey(for: now)
        // Completed challenges can't change until the day rolls over — skip
        // the (relatively expensive) regeneration in that case.
        if let cached = dailyState.value, cached.dateKey == todayKey, cached.isCompleted {
            return
        }
        if dailyState.value == nil {
            dailyState = .loading
        }
        dailyState = await .loaded(getDailyChallenge(now: now))
    }
}
