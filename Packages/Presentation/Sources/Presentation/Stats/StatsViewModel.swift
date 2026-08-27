public import Common
import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Statistics screen state: the aggregated overview.
@MainActor
@Observable
public final class StatsViewModel {
    public private(set) var state: ViewState<StatsOverview> = .idle

    @ObservationIgnored @Injected(\.computeStatsUseCase) private var computeStats

    public init() {}

    public func load(now: Date = Date()) async {
        if case .idle = state {
            state = .loading
        }
        let overview = await computeStats(today: now)
        state = overview.totalPlayed == 0 ? .empty : .loaded(overview)
    }
}
