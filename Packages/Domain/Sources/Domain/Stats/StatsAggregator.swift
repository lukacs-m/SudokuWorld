public import Foundation
public import Model

/// Pure aggregation from game records to the stats the UI renders. All
/// SwiftData access stays in the Data layer — this only sees plain values.
public struct StatsAggregator: Sendable {
    private let calendar: Calendar
    private let streaks: StreakCalculator

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
        streaks = StreakCalculator()
    }

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

        return StatsOverview(
            totalPlayed: records.count,
            totalWon: won,
            totalLost: lost,
            totalAbandoned: abandoned,
            streaks: streakInfo,
            perVariant: perVariantStats(records: records),
            gamesPerDay: gamesPerDay(records: records, today: today),
            winRateByDifficulty: winRateByDifficulty(records: records),
            timesByDifficulty: timesByDifficulty(records: records),
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
        )
    }

    private func perVariantStats(records: [GameRecord]) -> [VariantStats] {
        var cells: [VariantStats] = []
        for variant in SudokuVariant.allCases {
            for difficulty in Difficulty.allCases {
                let stats = variantStats(records: records, variant: variant, difficulty: difficulty)
                if stats.played > 0 {
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
        return (0 ..< windowDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else {
                return nil
            }
            return StatsOverview.DailyCount(day: day, count: counts[day] ?? 0)
        }.reversed()
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

    private func variantShares(records: [GameRecord]) -> [StatsOverview.VariantShare] {
        SudokuVariant.allCases.compactMap { variant in
            let played = records.count { $0.variant == variant }
            guard played > 0 else { return nil }
            return StatsOverview.VariantShare(variant: variant, played: played)
        }
    }
}
