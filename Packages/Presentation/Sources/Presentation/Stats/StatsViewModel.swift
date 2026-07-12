public import Common
import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Statistics screen state: the aggregated overview plus the banner slot.
@MainActor
@Observable
public final class StatsViewModel {
    public private(set) var state: ViewState<StatsOverview> = .idle
    public private(set) var banner: AdCreative?
    public private(set) var isPremium = false

    @ObservationIgnored @Injected(\.computeStatsUseCase) private var computeStats
    @ObservationIgnored @Injected(\.getBannerUseCase) private var getBanner
    @ObservationIgnored @Injected(\.getEntitlementsUseCase) private var getEntitlements

    public init() {}

    public func load(now: Date = Date()) async {
        if case .idle = state {
            state = .loading
        }
        let overview = await computeStats(today: now)
        state = overview.totalPlayed == 0 ? .empty : .loaded(overview)

        isPremium = await getEntitlements().isPremium
        banner = isPremium ? nil : await getBanner(placement: .statsBanner)
    }
}
