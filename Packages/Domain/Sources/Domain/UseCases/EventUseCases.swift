public import Foundation
public import Model

// MARK: - Daily challenge

/// Today's challenge: plan, deterministic puzzle, and completion status.
public protocol GetDailyChallengeUseCase: Sendable {
    func callAsFunction(now: Date) async -> DailyChallenge
}

public struct GetDailyChallenge: GetDailyChallengeUseCase {
    private let dailyChallenges: any DailyChallengeRepository
    private let generator = PuzzleGenerator()

    public init(dailyChallenges: any DailyChallengeRepository) {
        self.dailyChallenges = dailyChallenges
    }

    public func callAsFunction(now: Date) async -> DailyChallenge {
        let dateKey = EventSeeds.dailyDateKey(for: now)
        let plan = EventSeeds.dailyPlan(dateKey: dateKey)
        let puzzle = await generator.generate(
            variant: plan.variant,
            difficulty: plan.difficulty,
            seed: EventSeeds.dailySeed(dateKey: dateKey),
        )
        let completionTime = try? await dailyChallenges.completionTime(dateKey: dateKey)
        return DailyChallenge(
            dateKey: dateKey,
            endsAt: EventSeeds.nextDailyReset(after: now),
            puzzle: puzzle,
            isCompleted: completionTime != nil,
            completionTime: completionTime,
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
