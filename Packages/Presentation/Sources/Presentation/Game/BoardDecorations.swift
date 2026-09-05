import Model
import SwiftUI

/// Canvas helpers for the board's structural layers: box shading, windoku
/// windows, diagonals, parity marks, and grid lines. Everything is driven by
/// the topology, so samurai and mini boards render through the same code.
enum BoardDecorations {
    /// Alternating box shading plus tinted windoku windows.
    static func drawShading(
        _ context: GraphicsContext,
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        for index in 0 ..< topology.cellCount where topology.boxIndex[index] % 2 == 1 {
            context.fill(
                Path(cellRect(index, topology: topology, cellSize: cellSize)),
                with: .color(theme.cellBackgroundAlternate),
            )
        }
        for window in topology.windows {
            for index in window {
                context.fill(
                    Path(cellRect(index, topology: topology, cellSize: cellSize)),
                    with: .color(theme.accent.opacity(0.10)),
                )
            }
        }
    }

    /// The two X-Sudoku diagonals, drawn under the digits.
    static func drawDiagonals(
        _ context: GraphicsContext,
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        for diagonal in topology.diagonals {
            guard let first = diagonal.first, let last = diagonal.last else { continue }
            var path = Path()
            path.move(to: cellCenter(first, topology: topology, cellSize: cellSize))
            path.addLine(to: cellCenter(last, topology: topology, cellSize: cellSize))
            context.stroke(
                path,
                with: .color(theme.accent.opacity(0.25)),
                lineWidth: max(2, cellSize * 0.10),
            )
        }
    }

    /// Even-Odd marks: a circle outline for odd cells, a rounded square for
    /// even cells.
    static func drawParityMarks(
        _ context: GraphicsContext,
        parities: [Int: CellParity],
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        for (index, parity) in parities {
            let rect = cellRect(index, topology: topology, cellSize: cellSize)
                .insetBy(dx: cellSize * 0.10, dy: cellSize * 0.10)
            let path = switch parity {
            case .odd:
                Path(ellipseIn: rect)

            case .even:
                Path(roundedRect: rect, cornerRadius: cellSize * 0.12)
            }
            context.stroke(
                path,
                with: .color(theme.noteText.opacity(0.55)),
                lineWidth: 1.5,
            )
        }
    }

    /// Thin lines between cells, bold lines on box boundaries and the outer
    /// rim of the active area (handles samurai's irregular outline).
    static func drawGridLines(
        _ context: GraphicsContext,
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        var thin = Path()
        var bold = Path()

        for index in 0 ..< topology.cellCount {
            let position = topology.position(of: index)
            let rect = cellRect(index, topology: topology, cellSize: cellSize)
            let box = topology.boxIndex[index]

            // Top edge.
            appendEdge(
                from: CGPoint(x: rect.minX, y: rect.minY),
                to: CGPoint(x: rect.maxX, y: rect.minY),
                neighbor: topology.index(row: position.row - 1, col: position.col),
                box: box,
                topology: topology,
                thin: &thin,
                bold: &bold,
            )
            // Left edge.
            appendEdge(
                from: CGPoint(x: rect.minX, y: rect.minY),
                to: CGPoint(x: rect.minX, y: rect.maxY),
                neighbor: topology.index(row: position.row, col: position.col - 1),
                box: box,
                topology: topology,
                thin: &thin,
                bold: &bold,
            )
            // Bottom edge only when no active neighbor below (outer rim).
            if topology.index(row: position.row + 1, col: position.col) == nil {
                bold.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                bold.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            // Right edge only when no active neighbor to the right.
            if topology.index(row: position.row, col: position.col + 1) == nil {
                bold.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                bold.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
        }

        context.stroke(thin, with: .color(theme.gridLine), lineWidth: 0.75)
        context.stroke(bold, with: .color(theme.gridLineBold), lineWidth: 2)
    }

    // One edge needs the full drawing context (endpoints, neighbor, box,
    // topology, both paths); bundling them would just obscure the call sites.
    // swiftlint:disable:next function_parameter_count
    private static func appendEdge(
        from start: CGPoint,
        to end: CGPoint,
        neighbor: Int?,
        box: Int,
        topology: GridTopology,
        thin: inout Path,
        bold: inout Path,
    ) {
        if let neighbor {
            if topology.boxIndex[neighbor] != box {
                bold.move(to: start)
                bold.addLine(to: end)
            } else {
                thin.move(to: start)
                thin.addLine(to: end)
            }
        } else {
            bold.move(to: start)
            bold.addLine(to: end)
        }
    }

    // MARK: - Geometry

    static func cellRect(_ index: Int, topology: GridTopology, cellSize: CGFloat) -> CGRect {
        let position = topology.position(of: index)
        return CGRect(
            x: CGFloat(position.col) * cellSize,
            y: CGFloat(position.row) * cellSize,
            width: cellSize,
            height: cellSize,
        )
    }

    static func cellCenter(_ index: Int, topology: GridTopology, cellSize: CGFloat) -> CGPoint {
        let rect = cellRect(index, topology: topology, cellSize: cellSize)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    /// Where a pencil mark sits inside its cell: marks fill a small grid,
    /// three per row on 9×9 boards and wider on big grids.
    static func notePoint(for digit: Int, in rect: CGRect, size: Int) -> CGPoint {
        let noteColumns = VariantGlyphs.noteColumns(forSize: size)
        let noteRows = (size + noteColumns - 1) / noteColumns
        let column = (digit - 1) % noteColumns
        let row = (digit - 1) / noteColumns
        return CGPoint(
            x: rect.minX + rect.width * (CGFloat(column) + 0.5) / CGFloat(noteColumns),
            y: rect.minY + rect.height * (CGFloat(row) + 0.5) / CGFloat(noteRows),
        )
    }
}
