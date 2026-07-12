import Foundation
import Model

/// VoiceOver labels for board cells: position, content, and constraints,
/// assembled from catalog strings so they localize with everything else.
enum GameAccessibility {
    static func cellLabel(
        index: Int,
        board: Board,
        puzzle: PuzzleDefinition,
        topology: GridTopology,
    ) -> String {
        let position = topology.position(of: index)
        var parts: [String] = [
            String(
                format: String(localized: "a11y.cell.position", bundle: .module),
                position.row + 1,
                position.col + 1,
            ),
        ]

        let cell = board[index]
        if let value = cell.value {
            let key: String.LocalizationValue = cell.isGiven ? "a11y.cell.given" : "a11y.cell.value"
            parts.append(String(
                format: String(localized: key, bundle: .module),
                VariantGlyphs.glyph(value, for: puzzle.variant),
            ))
        } else if cell.notes.isEmpty {
            parts.append(String(localized: "a11y.cell.empty", bundle: .module))
        } else {
            let digits = cell.notes.digits
                .map { VariantGlyphs.glyph($0, for: puzzle.variant) }
                .joined(separator: ", ")
            parts.append(String(
                format: String(localized: "a11y.cell.notes", bundle: .module),
                digits,
            ))
        }

        if let parity = puzzle.parities[index] {
            let key: String.LocalizationValue = parity == .even
                ? "a11y.cell.even"
                : "a11y.cell.odd"
            parts.append(String(localized: key, bundle: .module))
        }
        if let cage = puzzle.cages.first(where: { $0.cells.contains(index) }) {
            parts.append(String(
                format: String(localized: "a11y.cell.cage", bundle: .module),
                cage.sum,
            ))
        }
        return parts.joined(separator: ", ")
    }

    /// Resolves a hint's explanation text from its key and arguments,
    /// rendering digits through the variant's glyph set.
    static func hintExplanation(_ hint: Hint, variant: SudokuVariant) -> String {
        expand(
            template: moduleString(hint.explanationKey),
            arguments: hint.explanationArguments.map {
                VariantGlyphs.text($0, variant: variant)
            },
        )
    }

    /// Substitutes positional `%n$@` placeholders (and a bare `%@` for
    /// single-argument templates). Split out so tests can exercise it without
    /// the string catalog, which CLI test hosts cannot resolve.
    static func expand(template: String, arguments: [String]) -> String {
        var result = template
        for (offset, argument) in arguments.enumerated() {
            result = result.replacingOccurrences(of: "%\(offset + 1)$@", with: argument)
        }
        if let first = arguments.first {
            result = result.replacingOccurrences(of: "%@", with: first)
        }
        return result
    }
}
