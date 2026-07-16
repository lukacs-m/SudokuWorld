import Model
import SwiftUI

/// Draws sandwich/skyscraper numbers and little-killer arrows in the gutter
/// band around the grid. Coordinates are in the outer (untranslated) space:
/// the grid itself starts at (gutter, gutter).
enum OutsideClueOverlay {
    static func draw(
        _ context: GraphicsContext,
        clues: [OutsideClue],
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
        gutter: CGFloat,
    ) {
        for clue in clues {
            let anchor = position(
                for: clue,
                topology: topology,
                cellSize: cellSize,
                gutter: gutter,
            )
            let label = Text("\(clue.value)")
                .font(.system(size: cellSize * 0.38, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
            context.draw(context.resolve(label), at: anchor, anchor: .center)

            if clue.kind == .diagonalSum {
                drawDiagonalArrow(
                    context,
                    clue: clue,
                    from: anchor,
                    cellSize: cellSize,
                    theme: theme,
                )
            }
        }
    }

    static func position(
        for clue: OutsideClue,
        topology: GridTopology,
        cellSize: CGFloat,
        gutter: CGFloat,
    ) -> CGPoint {
        let mid = gutter / 2

        if clue.kind == .diagonalSum {
            // The label must lie on the diagonal's own line so its arrow
            // reads unambiguously: step back from the corner where the
            // diagonal enters the grid, against the reading direction.
            let corner = entryCorner(
                for: clue,
                topology: topology,
                cellSize: cellSize,
                gutter: gutter,
            )
            let direction = diagonalDirection(for: clue.side)
            return CGPoint(
                x: corner.x - direction.dx * mid,
                y: corner.y - direction.dy * mid,
            )
        }

        let along = gutter + (CGFloat(clue.offset) + 0.5) * cellSize
        let farX = gutter + CGFloat(topology.colCount) * cellSize + mid
        let farY = gutter + CGFloat(topology.rowCount) * cellSize + mid
        return switch clue.side {
        case .leading: CGPoint(x: mid, y: along)
        case .trailing: CGPoint(x: farX, y: along)
        case .top: CGPoint(x: along, y: mid)
        case .bottom: CGPoint(x: along, y: farY)
        }
    }

    /// The grid corner where a little-killer diagonal enters: the line
    /// through the cell centers of top ↘ (0, offset), trailing ↙
    /// (offset, last), bottom ↖ (last, offset), leading ↗ (offset, 0),
    /// extended half a cell back out of the grid.
    private static func entryCorner(
        for clue: OutsideClue,
        topology: GridTopology,
        cellSize: CGFloat,
        gutter: CGFloat,
    ) -> CGPoint {
        let along = gutter + CGFloat(clue.offset) * cellSize
        let alongAfter = gutter + CGFloat(clue.offset + 1) * cellSize
        let farX = gutter + CGFloat(topology.colCount) * cellSize
        let farY = gutter + CGFloat(topology.rowCount) * cellSize
        return switch clue.side {
        case .top: CGPoint(x: along, y: gutter)
        case .trailing: CGPoint(x: farX, y: along)
        case .bottom: CGPoint(x: alongAfter, y: farY)
        case .leading: CGPoint(x: gutter, y: alongAfter)
        }
    }

    /// Screen-space reading direction per side: top ↘, trailing ↙,
    /// bottom ↖, leading ↗ (matching the engine).
    private static func diagonalDirection(for side: OutsideClue.Side) -> CGVector {
        switch side {
        case .top: CGVector(dx: 1, dy: 1)
        case .trailing: CGVector(dx: -1, dy: 1)
        case .bottom: CGVector(dx: -1, dy: -1)
        case .leading: CGVector(dx: 1, dy: -1)
        }
    }

    /// A short arrow beside a little-killer value showing which diagonal it
    /// reads: top ↘, trailing ↙, bottom ↖, leading ↗ (matching the engine).
    private static func drawDiagonalArrow(
        _ context: GraphicsContext,
        clue: OutsideClue,
        from anchor: CGPoint,
        cellSize: CGFloat,
        theme: Theme,
    ) {
        let direction = diagonalDirection(for: clue.side)
        let start = CGPoint(
            x: anchor.x + direction.dx * cellSize * 0.22,
            y: anchor.y + direction.dy * cellSize * 0.22,
        )
        let end = CGPoint(
            x: anchor.x + direction.dx * cellSize * 0.5,
            y: anchor.y + direction.dy * cellSize * 0.5,
        )
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = cellSize * 0.14
        for side in [angle + .pi * 0.75, angle - .pi * 0.75] {
            path.move(to: end)
            path.addLine(to: CGPoint(
                x: end.x + cos(side) * head,
                y: end.y + sin(side) * head,
            ))
        }
        context.stroke(
            path,
            with: .color(theme.textSecondary),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round),
        )
    }
}
