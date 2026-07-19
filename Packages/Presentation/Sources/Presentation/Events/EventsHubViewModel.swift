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

    /// Date keys of every completed daily challenge, for the week strip and
    /// the completion-rate tile.
    public private(set) var completedDayKeys: Set<String> = []
    public private(set) var streaks: StreakInfo = .zero

    @ObservationIgnored @Injected(\.getDailyChallengeUseCase) private var getDailyChallenge
    @ObservationIgnored @Injected(\.getWeeklyTournamentUseCase) private var getWeeklyTournament
    @ObservationIgnored @Injected(\.getStandingsUseCase) private var getStandings
    @ObservationIgnored @Injected(\.observeGameCenterAuthUseCase) private var observeAuth
    @ObservationIgnored @Injected(\.getBannerUseCase) private var getBanner
    @ObservationIgnored @Injected(\.getEntitlementsUseCase) private var getEntitlements
    @ObservationIgnored @Injected(\.dailyChallengeRepository) private var dailyChallenges
    @ObservationIgnored @Injected(\.computeStatsUseCase) private var computeStats

    public init() {}

    /// Completed daily challenges over the trailing 30 days, as a share.
    public var completionRate: Double {
        let calendar = EventSeeds.utcCalendar
        let today = Date()
        let completed = (0 ..< 30).count { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return false
            }
            return completedDayKeys.contains(EventSeeds.dailyDateKey(for: day))
        }
        return Double(completed) / 30
    }

    public func load(now: Date = Date()) async {
        if case .idle = state {
            state = .loading
        }
        let weekly = await getWeeklyTournament(now: now)
        let daily = await getDailyChallenge(now: now)
        state = .loaded(Content(daily: daily, weekly: weekly))

        completedDayKeys = await (try? dailyChallenges.completedDateKeys()) ?? []
        streaks = await computeStats(today: now).streaks

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
