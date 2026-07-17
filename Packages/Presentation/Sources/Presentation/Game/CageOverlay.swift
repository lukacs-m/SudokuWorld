import Model
import SwiftUI

/// Killer-cage rendering: dashed inset outlines hugging each cage's shape,
/// with the sum in the cage's top-left corner.
enum CageOverlay {
    static func draw(
        _ context: GraphicsContext,
        cages: [Cage],
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        let inset = cellSize * 0.07
        for cage in cages {
            context.stroke(
                outline(for: cage, topology: topology, cellSize: cellSize, inset: inset),
                with: .color(theme.noteText.opacity(0.8)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 2]),
            )

            // Sum label at the top-left-most cell (lowest index in row-major
            // order is the topmost, then leftmost).
            if let anchor = cage.cells.min() {
                let rect = BoardDecorations.cellRect(
                    anchor,
                    topology: topology,
                    cellSize: cellSize,
                )
                let text = Text("\(cage.sum)")
                    .font(.system(size: max(8, cellSize * 0.22), weight: .semibold))
                    .foregroundStyle(theme.noteText)
                context.draw(
                    context.resolve(text),
                    at: CGPoint(
                        x: rect.minX + inset + cellSize * 0.10,
                        y: rect.minY + inset + cellSize * 0.10,
                    ),
                    anchor: .center,
                )
            }
        }
    }

    /// The dashed outline hugging the cage's cells.
    private static func outline(
        for cage: Cage,
        topology: GridTopology,
        cellSize: CGFloat,
        inset: CGFloat,
    ) -> Path {
        let members = Set(cage.cells)
        var path = Path()

        for index in cage.cells {
            let position = topology.position(of: index)
            let rect = BoardDecorations
                .cellRect(index, topology: topology, cellSize: cellSize)
                .insetBy(dx: inset, dy: inset)
            let outer = BoardDecorations.cellRect(
                index,
                topology: topology,
                cellSize: cellSize,
            )

            func inCage(_ row: Int, _ col: Int) -> Bool {
                topology.index(row: row, col: col).map(members.contains) ?? false
            }

            let up = inCage(position.row - 1, position.col)
            let down = inCage(position.row + 1, position.col)
            let left = inCage(position.row, position.col - 1)
            let right = inCage(position.row, position.col + 1)

            // Edges: drawn at the inset rect, extended to the outer rect
            // toward cage neighbors so segments join up.
            if !up {
                path.move(to: CGPoint(x: left ? outer.minX : rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: right ? outer.maxX : rect.maxX, y: rect.minY))
            }
            if !down {
                path.move(to: CGPoint(x: left ? outer.minX : rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: right ? outer.maxX : rect.maxX, y: rect.maxY))
            }
            if !left {
                path.move(to: CGPoint(x: rect.minX, y: up ? outer.minY : rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: down ? outer.maxY : rect.maxY))
            }
            if !right {
                path.move(to: CGPoint(x: rect.maxX, y: up ? outer.minY : rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: down ? outer.maxY : rect.maxY))
            }
        }
        return path
    }
}
