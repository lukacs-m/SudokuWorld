public import Foundation
public import Model

/// Pure mapping from a finished game (plus aggregate context) to achievement
/// progress. No GameKit anywhere near it — fully unit-testable.
public struct AchievementEvaluator: Sendable {
    /// The variants counted by the "variety" achievement. Samurai is the
    /// flag-gated stretch variant and has its own dedicated achievement.
    public static let varietyVariants: [SudokuVariant] = [
        .classic, .mini6, .killer, .diagonal, .windoku, .evenOdd,
    ]

    public struct Input: Sendable {
        public let record: GameRecord
        /// Total wins across history, including this record.
        public let totalWins: Int
        /// Current daily-challenge streak, including today when applicable.
        public let dailyStreak: Int
        /// Variants with at least one win across history, including this one.
        public let variantsWon: Set<SudokuVariant>
        /// The player's weekly tournament rank after submitting, when known.
        public let weeklyRank: Int?

        public init(
            record: GameRecord,
            totalWins: Int,
            dailyStreak: Int,
            variantsWon: Set<SudokuVariant>,
            weeklyRank: Int?,
        ) {
            self.record = record
            self.totalWins = totalWins
            self.dailyStreak = dailyStreak
            self.variantsWon = variantsWon
            self.weeklyRank = weeklyRank
        }
    }

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Every achievement whose progress moved because of this game.
    public func progress(for input: Input) -> [AchievementProgress] {
        var results: [AchievementProgress] = []
        let record = input.record
        let won = record.outcome == .won

        if won {
            results.append(AchievementProgress(achievement: .firstWin, percent: 100))
            results.append(milestone(.wins10, value: input.totalWins, goal: 10))
            results.append(milestone(.wins100, value: input.totalWins, goal: 100))
            results.append(milestone(.wins1000, value: input.totalWins, goal: 1000))

            if record.variant == .classic, record.difficulty == .expert, record.duration < 180 {
                results.append(AchievementProgress(achievement: .speedExpert3, percent: 100))
            }
            if record.difficulty == .master, record.duration < 300 {
                results.append(AchievementProgress(achievement: .speedMaster5, percent: 100))
            }
            if record.difficulty == .expert, record.hintsUsed == 0, !record.usedReveal {
                results.append(AchievementProgress(achievement: .noHintExpert, percent: 100))
            }
            if record.mode == .hardcore, record.difficulty == .hard, record.mistakes == 0 {
                results.append(AchievementProgress(achievement: .flawlessHard, percent: 100))
            }
            if record.variant == .killer, record.difficulty == .master {
                results.append(AchievementProgress(achievement: .killerMaster, percent: 100))
            }
            if record.variant == .samurai {
                results.append(AchievementProgress(achievement: .samurai, percent: 100))
            }
            if record.context.dailyDateKey != nil {
                results.append(AchievementProgress(achievement: .dailyFirst, percent: 100))
            }

            let varietyCount = Self.varietyVariants.count { input.variantsWon.contains($0) }
            results.append(milestone(
                .variety,
                value: varietyCount,
                goal: Self.varietyVariants.count,
            ))

            let hour = calendar.component(.hour, from: record.finishedAt)
            if hour < 4 {
                results.append(AchievementProgress(achievement: .night, percent: 100))
            }
        }

        if input.dailyStreak > 0 {
            results.append(milestone(.streak7, value: input.dailyStreak, goal: 7))
            results.append(milestone(.streak30, value: input.dailyStreak, goal: 30))
        }
        if let rank = input.weeklyRank, rank <= 3 {
            results.append(AchievementProgress(achievement: .weeklyPodium, percent: 100))
        }

        // Only report achievements that actually have progress.
        return results.filter { $0.percent > 0 }
    }

    private func milestone(
        _ achievement: GameCenterIDs.Achievement,
        value: Int,
        goal: Int,
    ) -> AchievementProgress {
        AchievementProgress(
            achievement: achievement,
            percent: Double(value) / Double(goal) * 100,
        )
    }
}
