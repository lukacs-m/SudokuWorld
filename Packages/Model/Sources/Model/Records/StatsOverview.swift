public import Foundation

/// Everything the Statistics screen renders, precomputed into chart-friendly
/// series so the view stays dumb.
public struct StatsOverview: Equatable, Sendable {
    /// Finished games per calendar day (for the activity chart).
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
    public let streaks: StreakInfo
    /// One entry per variant × difficulty that has at least one finished game.
    public let perVariant: [VariantStats]
    public let gamesPerDay: [DailyCount]
    public let winRateByDifficulty: [DifficultyWinRate]
    public let timesByDifficulty: [DifficultyTimes]
    public let variantShares: [VariantShare]

    public var winRate: Double {
        totalPlayed > 0 ? Double(totalWon) / Double(totalPlayed) : 0
    }

    public static let empty = StatsOverview(
        totalPlayed: 0,
        totalWon: 0,
        totalLost: 0,
        totalAbandoned: 0,
        streaks: .zero,
        perVariant: [],
        gamesPerDay: [],
        winRateByDifficulty: [],
        timesByDifficulty: [],
        variantShares: [],
    )

    public init(
        totalPlayed: Int,
        totalWon: Int,
        totalLost: Int,
        totalAbandoned: Int,
        streaks: StreakInfo,
        perVariant: [VariantStats],
        gamesPerDay: [DailyCount],
        winRateByDifficulty: [DifficultyWinRate],
        timesByDifficulty: [DifficultyTimes],
        variantShares: [VariantShare],
    ) {
        self.totalPlayed = totalPlayed
        self.totalWon = totalWon
        self.totalLost = totalLost
        self.totalAbandoned = totalAbandoned
        self.streaks = streaks
        self.perVariant = perVariant
        self.gamesPerDay = gamesPerDay
        self.winRateByDifficulty = winRateByDifficulty
        self.timesByDifficulty = timesByDifficulty
        self.variantShares = variantShares
    }
}
