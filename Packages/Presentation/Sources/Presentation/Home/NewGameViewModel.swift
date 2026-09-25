import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Today's lineup for the free-tier access decision, best-time lookups and
/// the stored hardcore default for the difficulty step of the new-game flow.
@MainActor
@Observable
public final class NewGameViewModel {
    public private(set) var stats: [VariantStats] = []
    public private(set) var lineup: DailyLineup?
    public private(set) var hardcoreByDefault = false

    @ObservationIgnored @Injected(\.computeStatsUseCase) private var computeStats
    @ObservationIgnored @Injected(\.getDailyLineupUseCase) private var getDailyLineup
    @ObservationIgnored @Injected(\.settingsRepository) private var settingsRepository

    public init() {}

    public func load(now: Date = Date()) async {
        hardcoreByDefault = await settingsRepository.gameSettings().hardcoreByDefault
        lineup = await getDailyLineup(dateKey: EventSeeds.dailyDateKey(for: now))
        stats = await computeStats(today: now, firstWeekday: DailyDayGrid.firstWeekday)
            .perVariant
    }

    public func bestTime(variant: SudokuVariant, difficulty: Difficulty) -> TimeInterval? {
        stats.first { $0.variant == variant && $0.difficulty == difficulty }?.fastestTime
    }
}
