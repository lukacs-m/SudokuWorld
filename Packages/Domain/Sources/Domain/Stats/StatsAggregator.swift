public import Foundation
public import Model

/// Pure aggregation from game records to the stats the UI renders. All
/// SwiftData access stays in the Data layer — this only sees plain values.
/// Every day bucket uses the UTC calendar the daily challenge and the streak
/// key on, so activity, counters, trends and streaks never disagree.
public struct StatsAggregator: Sendable {
    private let calendar = EventSeeds.utcCalendar
    private let streaks = StreakCalculator()

    public init() {}

    public func overview(
        records: [GameRecord],
        dailyCompletionKeys: Set<String>,
        today: Date,
    ) -> StatsOverview {
        let won = records.count { $0.outcome == .won }
        let lost = records.count { $0.outcome == .lost }
        let abandoned = records.count { $0.outcome == .abandoned }

        let daily = streaks.dailyStreak(completedDateKeys: dailyCompletionKeys, today: today)
        let wins = streaks.winStreaks(records: records)
        let streakInfo = StreakInfo(
            currentDailyStreak: daily.current,
            bestDailyStreak: daily.best,
            currentWinStreak: wins.current,
            bestWinStreak: wins.best,
        )

        let classic = records.filter { $0.variant == .classic }
        let recentStart = startOfWindow(days: StatsOverview.recentHistoryDays, today: today)
        return StatsOverview(
            totalPlayed: records.count,
            totalWon: won,
            totalLost: lost,
            totalAbandoned: abandoned,
            gamesToday: records.count { calendar.isDate($0.finishedAt, inSameDayAs: today) },
            gamesThisWeek: gamesThisWeek(records: records, today: today),
            averageMistakes: average(records.map(\.mistakes)),
            averageHints: average(records.map(\.hintsUsed)),
            perfectSolves: records.count(where: isPerfectSolve),
            streaks: streakInfo,
            perVariant: masteryGrid(records: records),
            gamesPerDay: gamesPerDay(records: records, today: today),
            classicWinRateByDifficulty: winRateByDifficulty(records: classic),
            classicTimesByDifficulty: timesByDifficulty(records: classic),
            recentClassicTimesByDifficulty: timesByDifficulty(
                records: classic.filter { $0.finishedAt >= recentStart },
            ),
            solveTimeTrendByDifficulty: trends(records: records, today: today, by: \.difficulty),
            solveTimeTrendByVariant: trends(records: records, today: today, by: \.variant),
            variantShares: variantShares(records: records),
        )
    }

    /// Aggregates for one variant × difficulty cell (used by detail screens
    /// and personal-best checks).
    public func variantStats(
        records: [GameRecord],
        variant: SudokuVariant,
        difficulty: Difficulty,
    ) -> VariantStats {
        let subset = records.filter { $0.variant == variant && $0.difficulty == difficulty }
        let winTimes = subset.filter { $0.outcome == .won }.map(\.duration)
        let streak = streaks.winStreaks(records: subset)
        return VariantStats(
            variant: variant,
            difficulty: difficulty,
            played: subset.count,
            won: subset.count { $0.outcome == .won },
            lost: subset.count { $0.outcome == .lost },
            abandoned: subset.count { $0.outcome == .abandoned },
            currentWinStreak: streak.current,
            bestWinStreak: streak.best,
            fastestTime: winTimes.min(),
            averageTime: winTimes.isEmpty ? nil : winTimes.reduce(0, +) / Double(winTimes.count),
            perfectSolves: subset.count(where: isPerfectSolve),
        )
    }

    /// A reveal already increments `hintsUsed`; the flag is checked anyway
    /// so the rule holds for any record, however it was produced.
    private func isPerfectSolve(_ record: GameRecord) -> Bool {
        record.outcome == .won && record.mistakes == 0
            && record.hintsUsed == 0 && !record.usedReveal
    }

    private func average(_ values: [Int]) -> Double {
        values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }

    /// Midnight UTC `days - 1` days ago, so the window spans `days` UTC days
    /// ending with today.
    private func startOfWindow(days: Int, today: Date) -> Date {
        let startOfToday = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: 1 - days, to: startOfToday) ?? startOfToday
    }

    private func gamesThisWeek(records: [GameRecord], today: Date) -> Int {
        let startOfToday = calendar.startOfDay(for: today)
        // Gregorian weekdays run Sunday = 1 ... Saturday = 7; the week here
        // starts on Monday.
        let daysSinceMonday = (calendar.component(.weekday, from: startOfToday) + 5) % 7
        guard let start = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfToday),
              let end = calendar.date(byAdding: .day, value: 7, to: start)
        else { return 0 }
        return records.count { $0.finishedAt >= start && $0.finishedAt < end }
    }

    /// Every offered tier of every variant, plus tiers a fold variant no
    /// longer offers but that still have records from before they were hidden.
    private func masteryGrid(records: [GameRecord]) -> [VariantStats] {
        var cells: [VariantStats] = []
        for variant in SudokuVariant.allCases {
            for difficulty in Difficulty.allCases {
                let stats = variantStats(records: records, variant: variant, difficulty: difficulty)
                if stats.played > 0 || variant.offeredDifficulties.contains(difficulty) {
                    cells.append(stats)
                }
            }
        }
        return cells
    }

    private func gamesPerDay(records: [GameRecord], today: Date) -> [StatsOverview.DailyCount] {
        let windowDays = 30
        let startOfToday = calendar.startOfDay(for: today)
        var counts: [Date: Int] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.finishedAt)
            counts[day, default: 0] += 1
        }
        let descending: [StatsOverview.DailyCount] = (0 ..< windowDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else {
                return nil
            }
            return StatsOverview.DailyCount(day: day, count: counts[day] ?? 0)
        }
        return descending.reversed()
    }

    private func winRateByDifficulty(records: [GameRecord]) -> [StatsOverview.DifficultyWinRate] {
        Difficulty.allCases.compactMap { difficulty in
            let subset = records.filter { $0.difficulty == difficulty }
            guard !subset.isEmpty else { return nil }
            return StatsOverview.DifficultyWinRate(
                difficulty: difficulty,
                played: subset.count,
                won: subset.count { $0.outcome == .won },
            )
        }
    }

    private func timesByDifficulty(records: [GameRecord]) -> [StatsOverview.DifficultyTimes] {
        Difficulty.allCases.compactMap { difficulty in
            let times = records
                .filter { $0.difficulty == difficulty && $0.outcome == .won }
                .map(\.duration)
            guard !times.isEmpty else { return nil }
            return StatsOverview.DifficultyTimes(
                difficulty: difficulty,
                fastest: times.min(),
                average: times.reduce(0, +) / Double(times.count),
            )
        }
    }

    /// One trend per key (difficulty or variant) with a win in the last 90
    /// UTC days; the 30-day series is the tail of the same points.
    private func trends<Key: Hashable>(
        records: [GameRecord],
        today: Date,
        by key: KeyPath<GameRecord, Key>,
    ) -> [Key: StatsOverview.SolveTimeTrend] {
        let start90 = startOfWindow(days: 90, today: today)
        let start30 = startOfWindow(days: 30, today: today)
        let wins = records.filter { $0.outcome == .won && $0.finishedAt >= start90 }
        var trends: [Key: StatsOverview.SolveTimeTrend] = [:]
        for (value, subset) in Dictionary(grouping: wins, by: { $0[keyPath: key] }) {
            let points = trendPoints(wins: subset)
            trends[value] = StatsOverview.SolveTimeTrend(
                last30Days: points.filter { $0.day >= start30 },
                last90Days: points,
            )
        }
        return trends
    }

    private func trendPoints(wins: [GameRecord]) -> [StatsOverview.TrendPoint] {
        let byDay = Dictionary(grouping: wins) { calendar.startOfDay(for: $0.finishedAt) }
        return byDay.keys.sorted().map { day in
            let times = byDay[day, default: []].map(\.duration)
            return StatsOverview.TrendPoint(
                day: day,
                averageTime: times.reduce(0, +) / Double(times.count),
            )
        }
    }

    private func variantShares(records: [GameRecord]) -> [StatsOverview.VariantShare] {
        SudokuVariant.allCases.compactMap { variant in
            let played = records.count { $0.variant == variant }
            guard played > 0 else { return nil }
            return StatsOverview.VariantShare(variant: variant, played: played)
        }
    }
}
