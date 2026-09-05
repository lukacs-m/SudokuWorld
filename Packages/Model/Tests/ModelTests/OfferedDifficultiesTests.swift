import Testing
@testable import Model

@Suite
struct OfferedDifficultiesTests {
    @Test func foldVariantsHideTheTiersTheyCannotReach() {
        #expect(SudokuVariant.tredoku.offeredDifficulties == [.beginner, .easy, .hard])
        #expect(SudokuVariant.cube.offeredDifficulties == [.beginner, .easy, .medium, .hard])
    }

    @Test func everyOtherVariantOffersAllSixTiers() {
        for variant in SudokuVariant.allCases where variant != .tredoku && variant != .cube {
            #expect(variant.offeredDifficulties == Difficulty.allCases)
        }
    }

    @Test func nearestOfferedTierKeepsOfferedTiersAndRoundsTiesDown() {
        #expect(SudokuVariant.tredoku.nearestOfferedDifficulty(to: .hard) == .hard)
        #expect(SudokuVariant.tredoku.nearestOfferedDifficulty(to: .medium) == .easy)
        #expect(SudokuVariant.tredoku.nearestOfferedDifficulty(to: .expert) == .hard)
        #expect(SudokuVariant.tredoku.nearestOfferedDifficulty(to: .master) == .hard)
        #expect(SudokuVariant.cube.nearestOfferedDifficulty(to: .medium) == .medium)
        #expect(SudokuVariant.cube.nearestOfferedDifficulty(to: .master) == .hard)
        #expect(SudokuVariant.classic.nearestOfferedDifficulty(to: .master) == .master)
    }
}
