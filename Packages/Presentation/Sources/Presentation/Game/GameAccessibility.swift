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
                value,
            ))
        } else if cell.notes.isEmpty {
            parts.append(String(localized: "a11y.cell.empty", bundle: .module))
        } else {
            let digits = cell.notes.digits.map(String.init).joined(separator: ", ")
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

    /// Resolves a hint's explanation text from its key and arguments.
    static func hintExplanation(_ hint: Hint) -> String {
        let template = String(
            localized: String.LocalizationValue(hint.explanationKey),
            bundle: .module,
        )
        var result = template
        for (offset, argument) in hint.explanationArgs.enumerated() {
            result = result.replacingOccurrences(of: "%\(offset + 1)$@", with: argument)
        }
        // Single-argument templates may use a bare %@.
        if let first = hint.explanationArgs.first {
            result = result.replacingOccurrences(of: "%@", with: first)
        }
        return result
    }
}
