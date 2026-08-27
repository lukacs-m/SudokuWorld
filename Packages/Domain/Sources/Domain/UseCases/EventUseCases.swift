public import Foundation
public import Model

// MARK: - Daily lineup

/// A day's lineup: the three slot plans plus their completion status.
/// Cheap — puzzles are only generated when a slot is actually launched.
public protocol GetDailyLineupUseCase: Sendable {
    func callAsFunction(dateKey: String) async -> DailyLineup
}

public struct GetDailyLineup: GetDailyLineupUseCase {
    private let dailyChallenges: any DailyChallengeRepository

    public init(dailyChallenges: any DailyChallengeRepository) {
        self.dailyChallenges = dailyChallenges
    }

    public func callAsFunction(dateKey: String) async -> DailyLineup {
        let times = await (try? dailyChallenges.completions(dateKey: dateKey)) ?? [:]
        let slots = EventSeeds.dailySlots(dateKey: dateKey).map { plan in
            DailyLineup.Slot(
                variant: plan.variant,
                difficulty: plan.difficulty,
                completionTime: times[plan.variant],
            )
        }
        let dayStart = EventSeeds.date(fromDateKey: dateKey) ?? .distantPast
        return DailyLineup(
            dateKey: dateKey,
            endsAt: EventSeeds.nextDailyReset(after: dayStart),
            slots: slots,
        )
    }
}

// MARK: - Weekly tournament

/// This week's tournament theme plus the local player's progress.
public protocol GetWeeklyTournamentUseCase: Sendable {
    func callAsFunction(now: Date) async -> WeeklyTournament
}

public struct GetWeeklyTournament: GetWeeklyTournamentUseCase {
    private let dailyChallenges: any DailyChallengeRepository

    public init(dailyChallenges: any DailyChallengeRepository) {
        self.dailyChallenges = dailyChallenges
    }

    public func callAsFunction(now: Date) async -> WeeklyTournament {
        let weekKey = EventSeeds.weekKey(for: now)
        let plan = EventSeeds.weeklyPlan(weekKey: weekKey)
        let score = try? await dailyChallenges.tournamentScore(weekKey: weekKey)
        return WeeklyTournament(
            weekKey: weekKey,
            variant: plan.variant,
            difficulty: plan.difficulty,
            endsAt: EventSeeds.weekEnd(for: now),
            points: score?.points ?? 0,
            gamesCounted: score?.gamesCounted ?? 0,
        )
    }
}

// MARK: - Standings

/// Leaderboard standings for the events hub.
public protocol GetStandingsUseCase: Sendable {
    func callAsFunction(leaderboardID: String, count: Int) async throws -> LeaderboardStandings
}

public struct GetStandings: GetStandingsUseCase {
    private let gameCenter: any GameCenterService

    public init(gameCenter: any GameCenterService) {
        self.gameCenter = gameCenter
    }

    public func callAsFunction(
        leaderboardID: String,
        count: Int,
    ) async throws -> LeaderboardStandings {
        try await gameCenter.standings(leaderboardID: leaderboardID, count: count)
    }
}
