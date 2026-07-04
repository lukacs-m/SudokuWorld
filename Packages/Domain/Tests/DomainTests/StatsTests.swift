import Foundation
import Testing
@testable import Domain
import Model

private func day(_ dateKey: String, hour: Int = 12) -> Date {
    let parts = dateKey.split(separator: "-").compactMap { Int($0) }
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    components.hour = hour
    return EventSeeds.utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

private func record(
    outcome: GameOutcome,
    variant: SudokuVariant = .classic,
    difficulty: Difficulty = .medium,
    mode: GameMode = .normal,
    duration: TimeInterval = 300,
    finishedAt: Date = day("2026-07-04"),
) -> GameRecord {
    GameRecord(
        id: UUID(),
        variant: variant,
        difficulty: difficulty,
        mode: mode,
        outcome: outcome,
        context: .regular,
        duration: duration,
        mistakes: 0,
        hintsUsed: 0,
        usedReveal: false,
        points: 0,
        startedAt: finishedAt.addingTimeInterval(-duration),
        finishedAt: finishedAt,
    )
}

@Suite
struct StreakCalculatorTests {
    private let calculator = StreakCalculator()

    @Test func emptyHistoryHasNoStreak() {
        let result = calculator.dailyStreak(completedDateKeys: [], today: day("2026-07-04"))
        #expect(result.current == 0)
        #expect(result.best == 0)
    }

    @Test func streakCountsBackFromToday() {
        let keys: Set<String> = ["2026-07-02", "2026-07-03", "2026-07-04"]
        let result = calculator.dailyStreak(completedDateKeys: keys, today: day("2026-07-04"))
        #expect(result.current == 3)
        #expect(result.best == 3)
    }

    @Test func streakSurvivesThroughYesterday() {
        // Today not yet completed: the streak holds until midnight.
        let keys: Set<String> = ["2026-07-02", "2026-07-03"]
        let result = calculator.dailyStreak(completedDateKeys: keys, today: day("2026-07-04"))
        #expect(result.current == 2)
    }

    @Test func gapBreaksTheStreak() {
        let keys: Set<String> = ["2026-07-01", "2026-07-02", "2026-07-04"]
        let result = calculator.dailyStreak(completedDateKeys: keys, today: day("2026-07-04"))
        #expect(result.current == 1)
        #expect(result.best == 2)
    }

    @Test func staleHistoryHasZeroCurrent() {
        let keys: Set<String> = ["2026-06-20", "2026-06-21", "2026-06-22"]
        let result = calculator.dailyStreak(completedDateKeys: keys, today: day("2026-07-04"))
        #expect(result.current == 0)
        #expect(result.best == 3)
    }

    @Test func monthBoundaryIsSeamless() {
        let keys: Set<String> = ["2026-06-29", "2026-06-30", "2026-07-01"]
        let result = calculator.dailyStreak(completedDateKeys: keys, today: day("2026-07-01"))
        #expect(result.current == 3)
    }

    @Test func winStreaksBreakOnLossAndAbandon() {
        let base = day("2026-07-01")
        let records = [
            record(outcome: .won, finishedAt: base),
            record(outcome: .won, finishedAt: base.addingTimeInterval(100)),
            record(outcome: .lost, finishedAt: base.addingTimeInterval(200)),
            record(outcome: .won, finishedAt: base.addingTimeInterval(300)),
            record(outcome: .won, finishedAt: base.addingTimeInterval(400)),
            record(outcome: .won, finishedAt: base.addingTimeInterval(500)),
            record(outcome: .abandoned, finishedAt: base.addingTimeInterval(600)),
            record(outcome: .won, finishedAt: base.addingTimeInterval(700)),
        ]
        let result = StreakCalculator().winStreaks(records: records)
        #expect(result.current == 1)
        #expect(result.best == 3)
    }
}

@Suite
struct StatsAggregatorTests {
    private var aggregator: StatsAggregator {
        StatsAggregator(calendar: EventSeeds.utcCalendar)
    }

    @Test func totalsAndWinRate() {
        let records = [
            record(outcome: .won),
            record(outcome: .won),
            record(outcome: .lost, mode: .hardcore),
            record(outcome: .abandoned),
        ]
        let overview = aggregator.overview(
            records: records,
            dailyCompletionKeys: [],
            today: day("2026-07-04"),
        )
        #expect(overview.totalPlayed == 4)
        #expect(overview.totalWon == 2)
        #expect(overview.totalLost == 1)
        #expect(overview.totalAbandoned == 1)
        #expect(overview.winRate == 0.5)
    }

    @Test func variantStatsComputeTimesOverWinsOnly() {
        let records = [
            record(outcome: .won, duration: 100),
            record(outcome: .won, duration: 300),
            record(outcome: .abandoned, duration: 50),
        ]
        let stats = aggregator.variantStats(
            records: records,
            variant: .classic,
            difficulty: .medium,
        )
        #expect(stats.played == 3)
        #expect(stats.won == 2)
        #expect(stats.fastestTime == 100)
        #expect(stats.averageTime == 200)
        #expect(stats.abandoned == 1)
    }

    @Test func emptyCellsAreOmittedFromPerVariant() {
        let overview = aggregator.overview(
            records: [record(outcome: .won, variant: .killer, difficulty: .hard)],
            dailyCompletionKeys: [],
            today: day("2026-07-04"),
        )
        #expect(overview.perVariant.count == 1)
        #expect(overview.perVariant.first?.variant == .killer)
        #expect(overview.perVariant.first?.difficulty == .hard)
    }

    @Test func gamesPerDayCoversThirtyDayWindow() {
        let overview = aggregator.overview(
            records: [
                record(outcome: .won, finishedAt: day("2026-07-04")),
                record(outcome: .won, finishedAt: day("2026-07-04")),
                record(outcome: .lost, mode: .hardcore, finishedAt: day("2026-07-01")),
                // Outside the window: ignored.
                record(outcome: .won, finishedAt: day("2026-01-01")),
            ],
            dailyCompletionKeys: [],
            today: day("2026-07-04"),
        )
        #expect(overview.gamesPerDay.count == 30)
        #expect(overview.gamesPerDay.last?.count == 2)
        #expect(overview.gamesPerDay.reduce(0) { $0 + $1.count } == 3)
    }

    @Test func streaksFlowIntoOverview() {
        let overview = aggregator.overview(
            records: [record(outcome: .won)],
            dailyCompletionKeys: ["2026-07-03", "2026-07-04"],
            today: day("2026-07-04"),
        )
        #expect(overview.streaks.currentDailyStreak == 2)
        #expect(overview.streaks.currentWinStreak == 1)
    }

    @Test func lossOnlyFromHardcore() {
        // Business rule: `lost` records only ever come from hardcore games —
        // aggregation just counts what it is given, so the rule lives in the
        // session/completion flow. This documents the expectation.
        let overview = aggregator.overview(
            records: [record(outcome: .lost, mode: .hardcore)],
            dailyCompletionKeys: [],
            today: day("2026-07-04"),
        )
        #expect(overview.totalLost == 1)
    }
}

@Suite
struct InterstitialPolicyTests {
    @Test func requiresEnoughGames() {
        let policy = InterstitialPolicy.standard
        let now = day("2026-07-04")
        #expect(!policy.allowsInterstitial(gamesFinishedSince: 2, lastShownAt: nil, now: now))
        #expect(policy.allowsInterstitial(gamesFinishedSince: 3, lastShownAt: nil, now: now))
    }

    @Test func honorsCooldown() {
        let policy = InterstitialPolicy.standard
        let now = day("2026-07-04")
        let justShown = now.addingTimeInterval(-60)
        #expect(!policy.allowsInterstitial(gamesFinishedSince: 5, lastShownAt: justShown, now: now))
        let longAgo = now.addingTimeInterval(-3600)
        #expect(policy.allowsInterstitial(gamesFinishedSince: 5, lastShownAt: longAgo, now: now))
    }
}
