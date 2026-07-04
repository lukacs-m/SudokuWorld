import Foundation
import Testing
@testable import Domain
import Model

private func makeRecord(
    variant: SudokuVariant = .classic,
    difficulty: Difficulty = .medium,
    mode: GameMode = .normal,
    outcome: GameOutcome = .won,
    context: GameContext = .regular,
    duration: TimeInterval = 400,
    mistakes: Int = 1,
    hintsUsed: Int = 0,
    usedReveal: Bool = false,
    finishedHour: Int = 14,
) -> GameRecord {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    var components = DateComponents()
    components.year = 2026
    components.month = 7
    components.day = 4
    components.hour = finishedHour
    let finished = calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    return GameRecord(
        id: UUID(),
        variant: variant,
        difficulty: difficulty,
        mode: mode,
        outcome: outcome,
        context: context,
        duration: duration,
        mistakes: mistakes,
        hintsUsed: hintsUsed,
        usedReveal: usedReveal,
        points: 0,
        startedAt: finished.addingTimeInterval(-duration),
        finishedAt: finished,
    )
}

private func makeInput(
    record: GameRecord,
    totalWins: Int = 1,
    dailyStreak: Int = 0,
    variantsWon: Set<SudokuVariant> = [.classic],
    weeklyRank: Int? = nil,
) -> AchievementEvaluator.Input {
    AchievementEvaluator.Input(
        record: record,
        totalWins: totalWins,
        dailyStreak: dailyStreak,
        variantsWon: variantsWon,
        weeklyRank: weeklyRank,
    )
}

@Suite
struct AchievementEvaluatorTests {
    /// UTC evaluator so the "night" hour check is deterministic in CI.
    private var evaluator: AchievementEvaluator {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return AchievementEvaluator(calendar: calendar)
    }

    private func percent(
        _ achievement: GameCenterIDs.Achievement,
        in progress: [AchievementProgress],
    ) -> Double? {
        progress.first { $0.achievement == achievement }?.percent
    }

    @Test func firstWinFiresOnAnyWin() {
        let progress = evaluator.progress(for: makeInput(record: makeRecord()))
        #expect(percent(.firstWin, in: progress) == 100)
    }

    @Test func lossReportsNoWinAchievements() {
        let progress = evaluator.progress(
            for: makeInput(record: makeRecord(mode: .hardcore, outcome: .lost)),
        )
        #expect(percent(.firstWin, in: progress) == nil)
        #expect(percent(.wins10, in: progress) == nil)
    }

    @Test func winMilestonesReportIncrementalPercent() {
        let progress = evaluator.progress(
            for: makeInput(record: makeRecord(), totalWins: 5),
        )
        #expect(percent(.wins10, in: progress) == 50)
        #expect(percent(.wins100, in: progress) == 5)
        #expect(percent(.wins1000, in: progress) == 0.5)
    }

    @Test func winMilestoneCapsAtHundred() {
        let progress = evaluator.progress(
            for: makeInput(record: makeRecord(), totalWins: 250),
        )
        #expect(percent(.wins10, in: progress) == 100)
        #expect(percent(.wins100, in: progress) == 100)
        #expect(percent(.wins1000, in: progress) == 25)
    }

    @Test func speedExpertRequiresClassicExpertUnderThreeMinutes() {
        let fast = makeRecord(variant: .classic, difficulty: .expert, duration: 170)
        #expect(percent(.speedExpert3, in: evaluator.progress(for: makeInput(record: fast))) == 100)

        let slow = makeRecord(variant: .classic, difficulty: .expert, duration: 200)
        #expect(percent(.speedExpert3, in: evaluator.progress(for: makeInput(record: slow))) == nil)

        let wrongVariant = makeRecord(variant: .killer, difficulty: .expert, duration: 170)
        #expect(
            percent(.speedExpert3, in: evaluator.progress(for: makeInput(record: wrongVariant)))
                == nil,
        )
    }

    @Test func speedMasterAllowsAnyVariant() {
        let record = makeRecord(variant: .windoku, difficulty: .master, duration: 290)
        #expect(percent(.speedMaster5, in: evaluator.progress(for: makeInput(record: record))) == 100)
    }

    @Test func noHintExpertRejectsReveals() {
        let clean = makeRecord(difficulty: .expert, hintsUsed: 0)
        #expect(percent(.noHintExpert, in: evaluator.progress(for: makeInput(record: clean))) == 100)

        let revealed = makeRecord(difficulty: .expert, hintsUsed: 0, usedReveal: true)
        #expect(
            percent(.noHintExpert, in: evaluator.progress(for: makeInput(record: revealed))) == nil,
        )
    }

    @Test func flawlessHardNeedsHardcoreZeroMistakes() {
        let flawless = makeRecord(difficulty: .hard, mode: .hardcore, mistakes: 0)
        #expect(
            percent(.flawlessHard, in: evaluator.progress(for: makeInput(record: flawless))) == 100,
        )

        let normalMode = makeRecord(difficulty: .hard, mode: .normal, mistakes: 0)
        #expect(
            percent(.flawlessHard, in: evaluator.progress(for: makeInput(record: normalMode)))
                == nil,
        )
    }

    @Test func streaksReportIncrementally() {
        let progress = evaluator.progress(
            for: makeInput(record: makeRecord(context: .daily(dateKey: "2026-07-04")), dailyStreak: 14),
        )
        #expect(percent(.streak7, in: progress) == 100)
        #expect(percent(.streak30, in: progress).map { abs($0 - 1400.0 / 30.0) < 0.01 } == true)
    }

    @Test func varietyCountsCoreVariantsOnly() {
        let allCore: Set<SudokuVariant> = [.classic, .mini6, .killer, .diagonal, .windoku, .evenOdd]
        let progress = evaluator.progress(
            for: makeInput(record: makeRecord(), variantsWon: allCore.union([.samurai])),
        )
        #expect(percent(.variety, in: progress) == 100)

        let half = evaluator.progress(
            for: makeInput(record: makeRecord(), variantsWon: [.classic, .mini6, .killer]),
        )
        #expect(percent(.variety, in: half) == 50)
    }

    @Test func killerMasterAndSamurai() {
        let killer = makeRecord(variant: .killer, difficulty: .master)
        #expect(percent(.killerMaster, in: evaluator.progress(for: makeInput(record: killer))) == 100)

        let samurai = makeRecord(variant: .samurai, difficulty: .medium)
        #expect(percent(.samurai, in: evaluator.progress(for: makeInput(record: samurai))) == 100)
    }

    @Test func dailyFirstFiresOnDailyContext() {
        let daily = makeRecord(context: .daily(dateKey: "2026-07-04"))
        #expect(percent(.dailyFirst, in: evaluator.progress(for: makeInput(record: daily))) == 100)

        let regular = makeRecord()
        #expect(percent(.dailyFirst, in: evaluator.progress(for: makeInput(record: regular))) == nil)
    }

    @Test func weeklyPodiumNeedsTopThree() {
        let record = makeRecord(context: .weekly(weekKey: "2026-W27"))
        let third = evaluator.progress(for: makeInput(record: record, weeklyRank: 3))
        #expect(percent(.weeklyPodium, in: third) == 100)

        let fourth = evaluator.progress(for: makeInput(record: record, weeklyRank: 4))
        #expect(percent(.weeklyPodium, in: fourth) == nil)
    }

    @Test func nightOwlFiresBeforeFourAM() {
        let night = makeRecord(finishedHour: 3)
        #expect(percent(.night, in: evaluator.progress(for: makeInput(record: night))) == 100)

        let morning = makeRecord(finishedHour: 8)
        #expect(percent(.night, in: evaluator.progress(for: makeInput(record: morning))) == nil)
    }
}
