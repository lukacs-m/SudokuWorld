import Domain
import Foundation
import Model
import Testing

@testable import Presentation

struct MasteryMatrixLayoutTests {
    private let today = Date(timeIntervalSince1970: 1_783_000_000)

    private func record(
        variant: SudokuVariant,
        context: GameContext = .regular,
        outcome: GameOutcome = .won,
        mistakes: Int = 0,
        hintsUsed: Int = 0,
    ) -> GameRecord {
        GameRecord(
            id: UUID(),
            variant: variant,
            difficulty: .easy,
            mode: .normal,
            outcome: outcome,
            context: context,
            duration: 300,
            mistakes: mistakes,
            hintsUsed: hintsUsed,
            usedReveal: false,
            points: 0,
            startedAt: today.addingTimeInterval(-300),
            finishedAt: today,
        )
    }

    private func layout(_ records: [GameRecord]) -> MasteryMatrixLayout {
        MasteryMatrixLayout(overview: StatsAggregator().overview(
            records: records,
            dailyCompletionKeys: [],
            today: today,
            firstWeekday: 2,
        ))
    }

    @Test func aVariantTouchedOnlyThroughADailyRecordStaysVisible() {
        let result = layout([
            record(variant: .classic),
            record(variant: .kropki, context: .daily(dateKey: "2026-06-01", variant: .kropki)),
            record(variant: .arrow, context: .weekly(weekKey: "2026-W22"), outcome: .abandoned),
        ])
        #expect(result.touched.map(\.variant) == [.classic, .kropki, .arrow])
        #expect(result.locked.count == SudokuVariant.allCases.count - 3)
        #expect(!result.locked.contains { $0.variant == .kropki })
        #expect(result.rows.count == SudokuVariant.allCases.count)
    }

    @Test func everyRowIsLockedWithoutHistory() {
        let result = layout([])
        #expect(result.touched.isEmpty)
        #expect(result.locked.count == SudokuVariant.allCases.count)
    }

    @Test func rowsKeepTheAppsVariantOrderAndCellsTheDifficultyOrder() {
        let result = layout([record(variant: .cube), record(variant: .classic)])
        #expect(result.touched.map(\.variant) == [.classic, .cube])
        let cube = result.touched[1]
        #expect(cube.cells.map(\.difficulty) == SudokuVariant.cube.offeredDifficulties)
        #expect(cube.cell(for: .master) == nil)
        #expect(cube.cell(for: .easy)?.won == 1)
    }

    @Test func aTierTheVariantDoesNotOfferReadsApartFromAnUnplayedTier() throws {
        let result = layout([record(variant: .tredoku), record(variant: .cube)])
        let tredoku = try #require(result.rows.first { $0.variant == .tredoku })
        let cube = try #require(result.rows.first { $0.variant == .cube })
        #expect(tredoku.cell(for: .master) == nil)
        #expect(cube.cell(for: .beginner)?.played == 0)

        let notOffered = masteryCellLabel(difficulty: .master, cell: tredoku.cell(for: .master))
        let noGames = masteryCellLabel(difficulty: .beginner, cell: cube.cell(for: .beginner))
        #expect(notOffered.hasSuffix(moduleString("stats.mastery.cell.notOffered")))
        #expect(noGames.hasSuffix(moduleString("stats.mastery.cell.none")))
        #expect(
            masteryCellLabel(difficulty: .medium, cell: tredoku.cell(for: .medium))
                != masteryCellLabel(difficulty: .medium, cell: cube.cell(for: .medium)),
        )
    }

    @Test func perfectSolveBadgeNeedsAFlawlessWin() {
        let flawed = layout([
            record(variant: .classic, mistakes: 1),
            record(variant: .classic, hintsUsed: 1),
        ])
        #expect(flawed.touched[0].cell(for: .easy)?.won == 2)
        #expect(flawed.touched[0].cell(for: .easy)?.hasPerfectSolve == false)

        let flawless = layout([record(variant: .classic)])
        #expect(flawless.touched[0].cell(for: .easy)?.hasPerfectSolve == true)
    }
}
