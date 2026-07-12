import Model

/// Maps engine digits (always 1...size) to the symbols a variant displays:
/// hexadoku shows 0–F, wordoku letters. Exhaustive over `SudokuVariant` on
/// purpose: adding a case without deciding its glyph set must not compile.
enum VariantGlyphs {
    static func glyph(_ digit: Int, for variant: SudokuVariant) -> String {
        switch variant {
        case .hexadoku16:
            // Digits 1...16 display as hex 0...F.
            String(digit - 1, radix: 16).uppercased()
        case .wordoku:
            letter(digit, alphabet: "ABCDEFGHI")
        case .classic, .mini4, .mini6, .dodeka12, .killer, .diagonal, .windoku,
             .evenOdd, .samurai, .jigsaw, .argyle, .asterisk:
            "\(digit)"
        }
    }

    /// Renders a hint argument, glyphing digits and leaving coordinates
    /// numeric (rows and columns are counted, not symbolized).
    static func text(_ argument: Hint.Argument, variant: SudokuVariant) -> String {
        switch argument {
        case let .digit(digit):
            glyph(digit, for: variant)
        case let .digits(digits):
            digits.map { glyph($0, for: variant) }.joined(separator: ", ")
        case let .row(row):
            "\(row)"
        case let .column(column):
            "\(column)"
        }
    }

    /// Pencil-mark grid columns for a board of the given size.
    static func noteColumns(forSize size: Int) -> Int {
        switch size {
        case ...9: 3
        case ...16: 4
        default: 5
        }
    }

    private static func letter(_ digit: Int, alphabet: String) -> String {
        let index = alphabet.index(alphabet.startIndex, offsetBy: digit - 1)
        return String(alphabet[index])
    }
}
