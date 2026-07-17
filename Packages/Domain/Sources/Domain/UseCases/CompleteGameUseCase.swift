public import Foundation
public import Model

/// What the completion screen shows once a game ends.
public struct CompletionSummary: Equatable, Sendable {
    public let outcome: GameOutcome
    public let duration: TimeInterval
    public let mistakes: Int
    public let hintsUsed: Int
    public let isPersonalBest: Bool
    /// Achievements that hit 100% with this game.
    public let earnedAchievements: [GameCenterIDs.Achievement]
    public let dailyStreak: Int
    /// Tournament points earned by this game (0 outside weekly context).
    public let tournamentPoints: Int

    public init(
        outcome: GameOutcome,
        duration: TimeInterval,
        mistakes: Int,
        hintsUsed: Int,
        isPersonalBest: Bool,
        earnedAchievements: [GameCenterIDs.Achievement],
        dailyStreak: Int,
        tournamentPoints: Int,
    ) {
        self.outcome = outcome
        self.duration = duration
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.isPersonalBest = isPersonalBest
        self.earnedAchievements = earnedAchievements
        self.dailyStreak = dailyStreak
        self.tournamentPoints = tournamentPoints
    }
}

/// The single exit point for finished games: records the result, updates
/// event progress, reports achievements, and submits every relevant
/// leaderboard score. All Game Center work is fire-and-forget — completion
/// never blocks on the network.
public protocol CompleteGameUseCase: Sendable {
    func callAsFunction(
        session: GameSession,
        outcome: GameOutcome,
        at now: Date,
    ) async -> CompletionSummary
}

public struct CompleteGame: CompleteGameUseCase {
    private let gameRecords: any GameRecordRepository
    private let savedGames: any SavedGameRepository
    private let dailyChallenges: any DailyChallengeRepository
    private let gameCenter: any GameCenterService
    private let evaluator = AchievementEvaluator()
    private let streaks = StreakCalculator()

    public init(
        gameRecords: any GameRecordRepository,
        savedGames: any SavedGameRepository,
        dailyChallenges: any DailyChallengeRepository,
        gameCenter: any GameCenterService,
    ) {
        self.gameRecords = gameRecords
        self.savedGames = savedGames
        self.dailyChallenges = dailyChallenges
        self.gameCenter = gameCenter
    }

    public func callAsFunction(
        session: GameSession,
        outcome: GameOutcome,
        at now: Date,
    ) async -> CompletionSummary {
        let duration = session.elapsed(at: now)
        let won = outcome == .won

        var tournamentPoints = 0
        if won, session.context.weekKey != nil {
            tournamentPoints = Self.points(forWinDuration: duration)
        }

        let record = GameRecord(
            id: UUID(),
            variant: session.puzzle.variant,
            difficulty: session.puzzle.requestedDifficulty,
            mode: session.mode,
            outcome: outcome,
            context: session.context,
            duration: duration,
            mistakes: session.mistakes,
            hintsUsed: session.hintsUsed,
            usedReveal: session.usedReveal,
            points: tournamentPoints,
            startedAt: session.startedAt,
            finishedAt: now,
        )

        // Personal best is judged against history *before* this record lands.
        let priorRecords = await (try? gameRecords.allRecords()) ?? []
        let priorFastest = priorRecords
            .filter {
                $0.variant == record.variant
                    && $0.difficulty == record.difficulty
                    && $0.outcome == .won
            }
            .map(\.duration)
            .min()
        let isPersonalBest = won && (priorFastest.map { duration < $0 } ?? true)

        try? await gameRecords.insert(record)
        try? await savedGames.delete(context: session.context)

        if won, let dateKey = session.context.dailyDateKey {
            try? await dailyChallenges.markCompleted(dateKey: dateKey, duration: duration, at: now)
        }
        let weeklyCumulative = await updateTournamentScore(
            for: record,
            points: tournamentPoints,
        )

        let records = priorRecords + [record]
        let totalWins = records.count { $0.outcome == .won }
        let dailyKeys = await (try? dailyChallenges.completedDateKeys()) ?? []
        let dailyStreak = streaks.dailyStreak(completedDateKeys: dailyKeys, today: now)

        if won {
            await submitScores(
                record: record,
                records: records,
                totalWins: totalWins,
                bestDailyStreak: dailyStreak.best,
                weeklyCumulative: weeklyCumulative,
            )
        }

        let earned = await reportAchievements(
            record: record,
            records: records,
            totalWins: totalWins,
            dailyStreak: dailyStreak.current,
        )

        return CompletionSummary(
            outcome: outcome,
            duration: duration,
            mistakes: session.mistakes,
            hintsUsed: session.hintsUsed,
            isPersonalBest: isPersonalBest,
            earnedAchievements: earned,
            dailyStreak: dailyStreak.current,
            tournamentPoints: tournamentPoints,
        )
    }

    /// Tournament scoring: a base for winning plus a speed bonus.
    static func points(forWinDuration duration: TimeInterval) -> Int {
        500 + max(0, 600 - Int(duration))
    }

    private func updateTournamentScore(for record: GameRecord, points: Int) async -> Int? {
        guard record.outcome == .won, points > 0, let weekKey = record.context.weekKey else {
            return nil
        }
        var score = await (try? dailyChallenges.tournamentScore(weekKey: weekKey))
            ?? TournamentScore(weekKey: weekKey, points: 0, gamesCounted: 0, lastSubmittedPoints: 0)
        score.points += points
        score.gamesCounted += 1
        try? await dailyChallenges.saveTournamentScore(score)
        return score.points
    }

    private func submitScores(
        record: GameRecord,
        records: [GameRecord],
        totalWins: Int,
        bestDailyStreak: Int,
        weeklyCumulative: Int?,
    ) async {
        let centiseconds = Int(record.duration * 100)
        // Matrix boards exist only for the curated variants; everything else
        // still counts toward the aggregates below.
        if GameCenterIDs.leaderboardVariants.contains(record.variant) {
            await gameCenter.submitScore(
                centiseconds,
                leaderboardID: GameCenterIDs.leaderboard(.time, record.variant, record.difficulty),
            )

            let cellWins = records.count {
                $0.outcome == .won && $0.variant == record.variant
                    && $0.difficulty == record.difficulty
            }
            await gameCenter.submitScore(
                cellWins,
                leaderboardID: GameCenterIDs.leaderboard(.wins, record.variant, record.difficulty),
            )
        }
        await gameCenter.submitScore(totalWins, leaderboardID: GameCenterIDs.winsAll)
        if bestDailyStreak > 0 {
            await gameCenter.submitScore(bestDailyStreak, leaderboardID: GameCenterIDs.bestStreak)
        }
        if record.context.dailyDateKey != nil {
            await gameCenter.submitScore(centiseconds, leaderboardID: GameCenterIDs.daily)
        }
        if let weeklyCumulative, let weekKey = record.context.weekKey {
            await gameCenter.submitScore(weeklyCumulative, leaderboardID: GameCenterIDs.weekly)
            if var score = try? await dailyChallenges.tournamentScore(weekKey: weekKey) {
                score.lastSubmittedPoints = weeklyCumulative
                try? await dailyChallenges.saveTournamentScore(score)
            }
        }
    }

    private func reportAchievements(
        record: GameRecord,
        records: [GameRecord],
        totalWins: Int,
        dailyStreak: Int,
    ) async -> [GameCenterIDs.Achievement] {
        var weeklyRank: Int?
        if record.outcome == .won, record.context.weekKey != nil {
            weeklyRank = try? await gameCenter
                .standings(leaderboardID: GameCenterIDs.weekly, count: 3)
                .localEntry?.rank
        }

        let input = AchievementEvaluator.Input(
            record: record,
            totalWins: totalWins,
            dailyStreak: dailyStreak,
            variantsWon: Set(records.filter { $0.outcome == .won }.map(\.variant)),
            weeklyRank: weeklyRank,
        )
        let progress = evaluator.progress(for: input)
        if !progress.isEmpty {
            await gameCenter.report(progress)
        }
        return progress.filter { $0.percent >= 100 }.map(\.achievement)
    }
}
