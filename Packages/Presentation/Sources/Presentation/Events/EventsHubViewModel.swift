public import Common
import DI
import Domain
public import Foundation
public import Model
public import Observation

/// Events hub state: today's challenge, this week's tournament, standings
/// for both boards, and the Game Center auth state that gates them.
@MainActor
@Observable
public final class EventsHubViewModel {
    public struct Content: Equatable, Sendable {
        public let daily: DailyChallenge
        public let weekly: WeeklyTournament

        public init(daily: DailyChallenge, weekly: WeeklyTournament) {
            self.daily = daily
            self.weekly = weekly
        }
    }

    public private(set) var state: ViewState<Content> = .idle
    public private(set) var dailyStandings: ViewState<LeaderboardStandings> = .idle
    public private(set) var weeklyStandings: ViewState<LeaderboardStandings> = .idle
    public private(set) var authState: GameCenterAuthState = .unknown
    public private(set) var banner: AdCreative?
    public private(set) var isPremium = false

    @ObservationIgnored @Injected(\.getDailyChallengeUseCase) private var getDailyChallenge
    @ObservationIgnored @Injected(\.getWeeklyTournamentUseCase) private var getWeeklyTournament
    @ObservationIgnored @Injected(\.getStandingsUseCase) private var getStandings
    @ObservationIgnored @Injected(\.observeGameCenterAuthUseCase) private var observeAuth
    @ObservationIgnored @Injected(\.getBannerUseCase) private var getBanner
    @ObservationIgnored @Injected(\.getEntitlementsUseCase) private var getEntitlements

    public init() {}

    public func load(now: Date = Date()) async {
        if case .idle = state {
            state = .loading
        }
        let weekly = await getWeeklyTournament(now: now)
        let daily = await getDailyChallenge(now: now)
        state = .loaded(Content(daily: daily, weekly: weekly))

        isPremium = await getEntitlements().isPremium
        banner = isPremium ? nil : await getBanner(placement: .eventsBanner)

        await loadStandings()
    }

    /// Tracks authentication for the standings sections.
    public func observeAuthState() async {
        for await newState in observeAuth() {
            authState = newState
            if case .authenticated = newState {
                await loadStandings()
            }
        }
    }

    private func loadStandings() async {
        guard case .authenticated = authState else { return }
        dailyStandings = .loading
        weeklyStandings = .loading
        do {
            let standings = try await getStandings(
                leaderboardID: GameCenterIDs.daily,
                count: 10,
            )
            dailyStandings = standings.entries.isEmpty ? .empty : .loaded(standings)
        } catch {
            dailyStandings = .failed(String(localized: "events.standings.error", bundle: .module))
        }
        do {
            let standings = try await getStandings(
                leaderboardID: GameCenterIDs.weekly,
                count: 10,
            )
            weeklyStandings = standings.entries.isEmpty ? .empty : .loaded(standings)
        } catch {
            weeklyStandings = .failed(String(localized: "events.standings.error", bundle: .module))
        }
    }
}
