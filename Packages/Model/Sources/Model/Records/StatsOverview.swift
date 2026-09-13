public import Foundation

/// Everything the Statistics screen renders, precomputed into chart-friendly
/// series so the view stays dumb. Every day bucket is a UTC day — the clock
/// the daily challenge and the streak already run on.
public struct StatsOverview: Equatable, Sendable {
    /// The free tier's window for time-based stats; premium sees all time.
    public static let recentHistoryDays = 7

    /// Finished games per UTC day (for the activity chart).
    public struct DailyCount: Identifiable, Equatable, Sendable {
        public let day: Date
        public let count: Int

        public var id: Date {
            day
        }

        public init(day: Date, count: Int) {
            self.day = day
            self.count = count
        }
    }

    public struct DifficultyWinRate: Identifiable, Equatable, Sendable {
        public let difficulty: Difficulty
        public let played: Int
        public let won: Int

        public var id: Difficulty {
            difficulty
        }

        public var rate: Double {
            played > 0 ? Double(won) / Double(played) : 0
        }

        public init(difficulty: Difficulty, played: Int, won: Int) {
            self.difficulty = difficulty
            self.played = played
            self.won = won
        }
    }

    public struct DifficultyTimes: Identifiable, Equatable, Sendable {
        public let difficulty: Difficulty
        public let fastest: TimeInterval?
        public let average: TimeInterval?

        public var id: Difficulty {
            difficulty
        }

        public init(difficulty: Difficulty, fastest: TimeInterval?, average: TimeInterval?) {
            self.difficulty = difficulty
            self.fastest = fastest
            self.average = average
        }
    }

    /// Average solve time of one UTC day's wins.
    public struct TrendPoint: Identifiable, Equatable, Sendable {
        public let day: Date
        public let averageTime: TimeInterval

        public var id: Date {
            day
        }

        public init(day: Date, averageTime: TimeInterval) {
            self.day = day
            self.averageTime = averageTime
        }
    }

    /// Solve-time history for a line chart, wins only. Days without a win
    /// are left out rather than zero-filled, so sparse history plots as gaps.
    public struct SolveTimeTrend: Equatable, Sendable {
        public let last30Days: [TrendPoint]
        public let last90Days: [TrendPoint]

        public init(last30Days: [TrendPoint], last90Days: [TrendPoint]) {
            self.last30Days = last30Days
            self.last90Days = last90Days
        }
    }

    public struct VariantShare: Identifiable, Equatable, Sendable {
        public let variant: SudokuVariant
        public let played: Int

        public var id: SudokuVariant {
            variant
        }

        public init(variant: SudokuVariant, played: Int) {
            self.variant = variant
            self.played = played
        }
    }

    public let totalPlayed: Int
    public let totalWon: Int
    public let totalLost: Int
    public let totalAbandoned: Int
    /// Games finished today and in the current Monday to Sunday week (UTC),
    /// abandoned ones included like `totalPlayed`.
    public let gamesToday: Int
    public let gamesThisWeek: Int
    /// Mistakes and hints per finished game, over every game played.
    public let averageMistakes: Double
    public let averageHints: Double
    /// Wins with no mistakes and no hints (a reveal counts as a hint).
    public let perfectSolves: Int
    public let streaks: StreakInfo
    /// Every variant × offered difficulty, plus any hidden tier that still
    /// has history. Empty cells stay so the mastery matrix can show them.
    public let perVariant: [VariantStats]
    public let gamesPerDay: [DailyCount]
    public let classicWinRateByDifficulty: [DifficultyWinRate]
    /// Classic times over all history, and over the last `recentHistoryDays`.
    public let classicTimesByDifficulty: [DifficultyTimes]
    public let recentClassicTimesByDifficulty: [DifficultyTimes]
    /// Only keys with at least one win in the last 90 days are present.
    public let solveTimeTrendByDifficulty: [Difficulty: SolveTimeTrend]
    public let solveTimeTrendByVariant: [SudokuVariant: SolveTimeTrend]
    public let variantShares: [VariantShare]

    public var winRate: Double {
        totalPlayed > 0 ? Double(totalWon) / Double(totalPlayed) : 0
    }

    public static let empty = Self(
        totalPlayed: 0,
        totalWon: 0,
        totalLost: 0,
        totalAbandoned: 0,
        gamesToday: 0,
        gamesThisWeek: 0,
        averageMistakes: 0,
        averageHints: 0,
        perfectSolves: 0,
        streaks: .zero,
        perVariant: [],
        gamesPerDay: [],
        classicWinRateByDifficulty: [],
        classicTimesByDifficulty: [],
        recentClassicTimesByDifficulty: [],
        solveTimeTrendByDifficulty: [:],
        solveTimeTrendByVariant: [:],
        variantShares: [],
    )

    public init(
        totalPlayed: Int,
        totalWon: Int,
        totalLost: Int,
        totalAbandoned: Int,
        gamesToday: Int,
        gamesThisWeek: Int,
        averageMistakes: Double,
        averageHints: Double,
        perfectSolves: Int,
        streaks: StreakInfo,
        perVariant: [VariantStats],
        gamesPerDay: [DailyCount],
        classicWinRateByDifficulty: [DifficultyWinRate],
        classicTimesByDifficulty: [DifficultyTimes],
        recentClassicTimesByDifficulty: [DifficultyTimes],
        solveTimeTrendByDifficulty: [Difficulty: SolveTimeTrend],
        solveTimeTrendByVariant: [SudokuVariant: SolveTimeTrend],
        variantShares: [VariantShare],
    ) {
        self.totalPlayed = totalPlayed
        self.totalWon = totalWon
        self.totalLost = totalLost
        self.totalAbandoned = totalAbandoned
        self.gamesToday = gamesToday
        self.gamesThisWeek = gamesThisWeek
        self.averageMistakes = averageMistakes
        self.averageHints = averageHints
        self.perfectSolves = perfectSolves
        self.streaks = streaks
        self.perVariant = perVariant
        self.gamesPerDay = gamesPerDay
        self.classicWinRateByDifficulty = classicWinRateByDifficulty
        self.classicTimesByDifficulty = classicTimesByDifficulty
        self.recentClassicTimesByDifficulty = recentClassicTimesByDifficulty
        self.solveTimeTrendByDifficulty = solveTimeTrendByDifficulty
        self.solveTimeTrendByVariant = solveTimeTrendByVariant
        self.variantShares = variantShares
    }
}
