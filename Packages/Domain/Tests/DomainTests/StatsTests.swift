import Foundation
import Testing
@testable import Domain
import Model

private func day(_ dateKey: String, hour: Int = 12, minute: Int = 0) -> Date {
    let parts = dateKey.split(separator: "-").compactMap { Int($0) }
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    components.hour = hour
    components.minute = minute
    return EventSeeds.utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

private func record(
    outcome: GameOutcome,
    variant: SudokuVariant = .classic,
    difficulty: Difficulty = .medium,
    mode: GameMode = .normal,
    duration: TimeInterval = 300,
    mistakes: Int = 0,
    hintsUsed: Int = 0,
    usedReveal: Bool = false,
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
        mistakes: mistakes,
        hintsUsed: hintsUsed,
        usedReveal: usedReveal,
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

    @Test func slotsOnEitherSideOfUTCMidnightAreConsecutiveDays() {
        // Classic solved at 23:30 UTC, a variant slot at 00:30 UTC: the keys
        // the repository derives from those instants land on two days.
        let classicAt = day("2026-07-03", hour: 23, minute: 30)
        let variantAt = day("2026-07-04", hour: 0, minute: 30)
        let keys: Set<String> = [
            EventSeeds.dailyDateKey(for: classicAt),
            EventSeeds.dailyDateKey(for: variantAt),
        ]
        #expect(keys == ["2026-07-03", "2026-07-04"])
        let result = calculator.dailyStreak(completedDateKeys: keys, today: variantAt)
        #expect(result.current == 2)
    }

    @Test func dayKeysFollowUTCNotTheDeviceTimeZone() {
        // 20:30 on July 3 in Los Angeles is already July 4 in UTC, so a
        // completion then extends a streak that ended on July 3.
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        let evening = losAngeles.date(
            from: DateComponents(year: 2026, month: 7, day: 3, hour: 20, minute: 30),
        ) ?? Date(timeIntervalSince1970: 0)
        #expect(EventSeeds.dailyDateKey(for: evening) == "2026-07-04")

        let keys: Set<String> = ["2026-07-03", EventSeeds.dailyDateKey(for: evening)]
        let result = calculator.dailyStreak(completedDateKeys: keys, today: evening)
        #expect(result.current == 2)
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
    private let aggregator = StatsAggregator()

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

    @Test func perVariantIsTheFullGridOfOfferedTiers() {
        let overview = aggregator.overview(
            records: [record(outcome: .won, variant: .killer, difficulty: .hard)],
            dailyCompletionKeys: [],
            today: day("2026-07-04"),
        )
        let expectedCells = SudokuVariant.allCases.reduce(0) { $0 + $1.offeredDifficulties.count }
        #expect(overview.perVariant.count == expectedCells)
        let killerHard = overview.perVariant.first { $0.variant == .killer && $0.difficulty == .hard }
        #expect(killerHard?.won == 1)
        let untouched = overview.perVariant.first { $0.variant == .arrow && $0.difficulty == .easy }
        #expect(untouched?.played == 0)
        #expect(untouched?.fastestTime == nil)
        // A tier the fold variant hides has no cell without history.
        #expect(!overview.perVariant.contains { $0.variant == .tredoku && $0.difficulty == .master })
    }

    @Test func historyOnAHiddenTierStaysVisible() {
        // Tiers a fold variant no longer offers still have records from
        // before they were hidden; aggregation must keep showing them.
        let overview = aggregator.overview(
            records: [
                record(outcome: .won, variant: .tredoku, difficulty: .expert, duration: 400),
                record(outcome: .won, variant: .cube, difficulty: .master, duration: 600),
            ],
            dailyCompletionKeys: [],
            today: day("2026-07-04"),
        )
        let hidden = overview.perVariant.filter { $0.played > 0 }
        #expect(hidden.map(\.variant) == [.tredoku, .cube])
        #expect(hidden.map(\.difficulty) == [.expert, .master])
        let shared = overview.variantShares.map(\.variant).sorted { $0.slug < $1.slug }
        #expect(shared == [.cube, .tredoku])
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

    @Test func difficultySeriesAreClassicOnly() {
        let overview = aggregator.overview(
            records: [
                record(outcome: .won, difficulty: .easy, duration: 200),
                record(outcome: .lost, difficulty: .easy, mode: .hardcore),
                record(outcome: .won, variant: .killer, difficulty: .easy, duration: 50),
                record(outcome: .won, variant: .killer, difficulty: .hard, duration: 900),
            ],
            dailyCompletionKeys: [],
            today: day("2026-07-04"),
        )
        #expect(overview.classicWinRateByDifficulty.map(\.difficulty) == [.easy])
        #expect(overview.classicWinRateByDifficulty.first?.played == 2)
        #expect(overview.classicWinRateByDifficulty.first?.won == 1)
        #expect(overview.classicTimesByDifficulty.map(\.fastest) == [200])
    }

    @Test func recentTimesCoverTheLastSevenUTCDays() {
        let today = day("2026-07-10", hour: 8)
        let overview = aggregator.overview(
            records: [
                record(outcome: .won, duration: 500, finishedAt: day("2026-07-10", hour: 1)),
                // Six days back at midnight: the first instant of the window.
                record(outcome: .won, duration: 100, finishedAt: day("2026-07-04", hour: 0)),
                // Seven days back: outside, however late in the day.
                record(outcome: .won, duration: 50, finishedAt: day("2026-07-03", hour: 23)),
            ],
            dailyCompletionKeys: [],
            today: today,
        )
        #expect(overview.classicTimesByDifficulty.first?.fastest == 50)
        #expect(overview.recentClassicTimesByDifficulty.first?.fastest == 100)
        #expect(overview.recentClassicTimesByDifficulty.first?.average == 300)
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
struct StatsCounterTests {
    private let aggregator = StatsAggregator()

    private func overview(_ records: [GameRecord], today: Date) -> StatsOverview {
        aggregator.overview(records: records, dailyCompletionKeys: [], today: today)
    }

    @Test func todayCountsUTCDayAndIncludesAbandonedGames() {
        // Wednesday 2026-07-08, 02:00 UTC.
        let today = day("2026-07-08", hour: 2)
        let result = overview([
            record(outcome: .won, finishedAt: day("2026-07-08", hour: 0)),
            record(outcome: .abandoned, finishedAt: day("2026-07-08", hour: 23)),
            record(outcome: .won, finishedAt: day("2026-07-07", hour: 23, minute: 59)),
        ], today: today)
        #expect(result.gamesToday == 2)
    }

    @Test func weekRunsMondayToSundayInUTC() {
        // Wednesday 2026-07-08: the week is Mon 07-06 00:00 ... Sun 07-12 24:00.
        let today = day("2026-07-08")
        let result = overview([
            record(outcome: .won, finishedAt: day("2026-07-06", hour: 0)),
            record(outcome: .abandoned, finishedAt: day("2026-07-12", hour: 23, minute: 59)),
            record(outcome: .won, finishedAt: day("2026-07-05", hour: 23, minute: 59)),
            record(outcome: .won, finishedAt: day("2026-07-13", hour: 0)),
        ], today: today)
        #expect(result.gamesThisWeek == 2)
    }

    @Test func sundayBelongsToTheWeekThatStartedOnMonday() {
        let sunday = day("2026-07-12")
        let result = overview([
            record(outcome: .won, finishedAt: day("2026-07-06")),
            record(outcome: .won, finishedAt: day("2026-07-12")),
        ], today: sunday)
        #expect(result.gamesThisWeek == 2)
    }

    @Test func perfectSolvesNeedAWinWithNoMistakesAndNoHints() {
        let result = overview([
            record(outcome: .won),
            record(outcome: .won, mistakes: 1),
            record(outcome: .won, hintsUsed: 1),
            // A reveal is recorded as a hint by the session; the flag alone
            // must disqualify too.
            record(outcome: .won, hintsUsed: 1, usedReveal: true),
            record(outcome: .won, usedReveal: true),
            record(outcome: .lost, mode: .hardcore),
            record(outcome: .abandoned),
        ], today: day("2026-07-04"))
        #expect(result.perfectSolves == 1)
        #expect(result.perVariant.first { $0.variant == .classic && $0.difficulty == .medium }?
            .perfectSolves == 1)
    }

    @Test func mistakeAndHintAveragesSpanEveryGame() {
        let result = overview([
            record(outcome: .won, mistakes: 2, hintsUsed: 1),
            record(outcome: .abandoned, mistakes: 0, hintsUsed: 3),
        ], today: day("2026-07-04"))
        #expect(result.averageMistakes == 1)
        #expect(result.averageHints == 2)
        #expect(StatsOverview.empty.averageMistakes == 0)
    }
}

@Suite
struct SolveTimeTrendTests {
    private let aggregator = StatsAggregator()
    private let today = day("2026-07-04", hour: 8)

    private func overview(_ records: [GameRecord]) -> StatsOverview {
        aggregator.overview(records: records, dailyCompletionKeys: [], today: today)
    }

    @Test func noWinsMeansNoTrend() {
        let result = overview([record(outcome: .abandoned), record(outcome: .lost, mode: .hardcore)])
        #expect(result.solveTimeTrendByDifficulty.isEmpty)
        #expect(result.solveTimeTrendByVariant.isEmpty)
    }

    @Test func aSingleWinIsAOnePointSeries() {
        let result = overview([record(outcome: .won, duration: 420, finishedAt: today)])
        let trend = result.solveTimeTrendByDifficulty[.medium]
        #expect(trend?.last30Days.count == 1)
        #expect(trend?.last90Days.count == 1)
        #expect(trend?.last30Days.first?.averageTime == 420)
        #expect(trend?.last30Days.first?.day == day("2026-07-04", hour: 0))
        #expect(result.solveTimeTrendByVariant[.classic] == trend)
    }

    @Test func sparseWinsAverageByUTCDayAndSkipEmptyDays() {
        let result = overview([
            record(outcome: .won, duration: 100, finishedAt: day("2026-07-04", hour: 1)),
            record(outcome: .won, duration: 300, finishedAt: day("2026-07-04", hour: 23)),
            record(outcome: .won, duration: 500, finishedAt: day("2026-07-01")),
            record(outcome: .won, variant: .killer, duration: 700, finishedAt: day("2026-06-20")),
            record(outcome: .abandoned, duration: 5, finishedAt: day("2026-07-02")),
        ])
        let medium = result.solveTimeTrendByDifficulty[.medium]
        #expect(medium?.last30Days.map(\.averageTime) == [700, 500, 200])
        #expect(medium?.last30Days.map(\.day) == [
            day("2026-06-20", hour: 0), day("2026-07-01", hour: 0), day("2026-07-04", hour: 0),
        ])
        #expect(result.solveTimeTrendByVariant[.classic]?.last30Days.map(\.averageTime) == [500, 200])
        #expect(result.solveTimeTrendByVariant[.killer]?.last30Days.map(\.averageTime) == [700])
    }

    @Test func windowsSpanThirtyAndNinetyUTCDaysEndingToday() {
        let result = overview([
            record(outcome: .won, duration: 1, finishedAt: today),
            // Day 30 of the 30-day window (29 days back) is in; day 31 is out.
            record(outcome: .won, duration: 2, finishedAt: day("2026-06-05", hour: 0)),
            record(outcome: .won, duration: 3, finishedAt: day("2026-06-04", hour: 23, minute: 59)),
            // Same edge for the 90-day window.
            record(outcome: .won, duration: 4, finishedAt: day("2026-04-06", hour: 0)),
            record(outcome: .won, duration: 5, finishedAt: day("2026-04-05", hour: 23, minute: 59)),
        ])
        let trend = result.solveTimeTrendByDifficulty[.medium]
        #expect(trend?.last30Days.map(\.averageTime) == [2, 1])
        #expect(trend?.last90Days.map(\.averageTime) == [4, 3, 2, 1])
    }
}
