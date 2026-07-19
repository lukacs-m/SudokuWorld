import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Best-time lookups for the difficulty step of the new-game flow.
@MainActor
@Observable
public final class NewGameViewModel {
    public private(set) var stats: [VariantStats] = []

    @ObservationIgnored @Injected(\.computeStatsUseCase) private var computeStats

    public init() {}

    public func load(now: Date = Date()) async {
        stats = await computeStats(today: now).perVariant
    }

    public func bestTime(variant: SudokuVariant, difficulty: Difficulty) -> TimeInterval? {
        stats.first { $0.variant == variant && $0.difficulty == difficulty }?.fastestTime
    }
}
