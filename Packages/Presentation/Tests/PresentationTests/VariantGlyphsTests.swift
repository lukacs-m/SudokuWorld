import Model
import Testing
@testable import Presentation

@Suite
@MainActor
struct VariantGlyphsTests {
    @Test func numericVariantsShowPlainDigits() {
        #expect(VariantGlyphs.glyph(1, for: .classic) == "1")
        #expect(VariantGlyphs.glyph(12, for: .dodeka12) == "12")
    }

    @Test func hexadokuShowsHexRange() {
        #expect(VariantGlyphs.glyph(1, for: .hexadoku16) == "0")
        #expect(VariantGlyphs.glyph(10, for: .hexadoku16) == "9")
        #expect(VariantGlyphs.glyph(11, for: .hexadoku16) == "A")
        #expect(VariantGlyphs.glyph(16, for: .hexadoku16) == "F")
    }

    @Test func wordokuShowsLetters() {
        #expect(VariantGlyphs.glyph(1, for: .wordoku) == "A")
        #expect(VariantGlyphs.glyph(9, for: .wordoku) == "I")
    }

    @Test func alphadokuSpansTwentyFiveLetters() {
        #expect(VariantGlyphs.glyph(1, for: .alphadoku25) == "A")
        #expect(VariantGlyphs.glyph(25, for: .alphadoku25) == "Y")
    }

    @Test func everyVariantGlyphsItsFullDigitRange() {
        for variant in SudokuVariant.allCases {
            let size = TestTopologySizes.size(for: variant)
            let glyphs = (1 ... size).map { VariantGlyphs.glyph($0, for: variant) }
            #expect(Set(glyphs).count == size, "duplicate glyphs for \(variant)")
        }
    }

    @Test func noteColumnsScaleWithBoardSize() {
        #expect(VariantGlyphs.noteColumns(forSize: 4) == 3)
        #expect(VariantGlyphs.noteColumns(forSize: 9) == 3)
        #expect(VariantGlyphs.noteColumns(forSize: 12) == 4)
        #expect(VariantGlyphs.noteColumns(forSize: 16) == 4)
        #expect(VariantGlyphs.noteColumns(forSize: 25) == 5)
    }

    @Test func hintArgumentsRenderThroughGlyphs() {
        // The catalog template for hint.reveal, hardcoded because CLI test
        // hosts cannot resolve the string catalog.
        let template = "The cell at row %2$@, column %3$@ is %1$@."
        let arguments = [Hint.Argument.digit(12), .row(3), .column(4)].map {
            VariantGlyphs.text($0, variant: .hexadoku16)
        }
        let text = GameAccessibility.expand(template: template, arguments: arguments)
        #expect(text == "The cell at row 3, column 4 is B.")
    }
}

/// The digit range per variant, mirrored here so the glyph test doesn't need
/// the Domain topology factory.
private enum TestTopologySizes {
    static func size(for variant: SudokuVariant) -> Int {
        switch variant {
        case .mini4: 4
        case .mini6: 6
        case .dodeka12: 12
        case .hexadoku16: 16
        case .alphadoku25: 25
        case .classic, .killer, .diagonal, .windoku, .evenOdd, .samurai, .wordoku,
             .jigsaw, .argyle, .asterisk,
             .gattai2, .gattai3, .gattai8, .shogun, .sumo: 9
        }
    }
}
