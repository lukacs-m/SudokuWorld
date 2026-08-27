public import Common
import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Home screen state: the resumable game, streaks, and today's lineup.
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
    public private(set) var dailyState: ViewState<DailyLineup> = .idle

    @ObservationIgnored @Injected(\.resumeGameUseCase) private var resumeGame
    @ObservationIgnored @Injected(\.computeStatsUseCase) private var computeStats
    @ObservationIgnored @Injected(\.getDailyLineupUseCase) private var getDailyLineup

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

        await refreshDaily(now: now)
    }

    private func refreshDaily(now: Date) async {
        if dailyState.value == nil {
            dailyState = .loading
        }
        dailyState = await .loaded(getDailyLineup(
            dateKey: EventSeeds.dailyDateKey(for: now),
        ))
    }
}
