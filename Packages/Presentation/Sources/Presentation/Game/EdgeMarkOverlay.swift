import Model
import SwiftUI

/// Draws relation marks on the shared edge between two adjacent cells:
/// kropki dots, XV letters, consecutive bars, and futoshiki inequality
/// chevrons. Drawn above the grid lines so the marks sit on them.
enum EdgeMarkOverlay {
    /// The shared-edge geometry one mark needs: both cell centers, their
    /// midpoint, and the pair's orientation.
    private struct EdgeGeometry {
        let centerA: CGPoint
        let centerB: CGPoint
        let mid: CGPoint
        let horizontalPair: Bool

        init(centerA: CGPoint, centerB: CGPoint) {
            self.centerA = centerA
            self.centerB = centerB
            mid = CGPoint(x: (centerA.x + centerB.x) / 2, y: (centerA.y + centerB.y) / 2)
            horizontalPair = abs(centerA.y - centerB.y) < 0.5
        }
    }

    static func draw(
        _ context: GraphicsContext,
        relations: [RelationClue],
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        for clue in relations {
            let edge = EdgeGeometry(
                centerA: BoardDecorations.cellCenter(
                    clue.a,
                    topology: topology,
                    cellSize: cellSize,
                ),
                centerB: BoardDecorations.cellCenter(
                    clue.b,
                    topology: topology,
                    cellSize: cellSize,
                ),
            )

            switch clue.kind {
            case .whiteDot, .blackDot:
                drawDot(context, kind: clue.kind, edge: edge, theme: theme, cellSize: cellSize)

            case .xSum, .vSum:
                drawLetter(context, kind: clue.kind, edge: edge, theme: theme, cellSize: cellSize)

            case .consecutive:
                drawBar(context, edge: edge, theme: theme, cellSize: cellSize)

            case .greaterThan:
                drawChevron(context, edge: edge, theme: theme, cellSize: cellSize)
            }
        }
    }

    private static func drawDot(
        _ context: GraphicsContext,
        kind: RelationClue.Kind,
        edge: EdgeGeometry,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        let radius = cellSize * 0.14
        let dot = CGRect(
            x: edge.mid.x - radius,
            y: edge.mid.y - radius,
            width: radius * 2,
            height: radius * 2,
        )
        context.fill(
            Path(ellipseIn: dot),
            with: .color(kind == .blackDot ? theme.givenText : theme.cellBackground),
        )
        context.stroke(
            Path(ellipseIn: dot),
            with: .color(theme.givenText),
            lineWidth: 1,
        )
    }

    private static func drawLetter(
        _ context: GraphicsContext,
        kind: RelationClue.Kind,
        edge: EdgeGeometry,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        let radius = cellSize * 0.17
        let plaque = CGRect(
            x: edge.mid.x - radius,
            y: edge.mid.y - radius,
            width: radius * 2,
            height: radius * 2,
        )
        context.fill(Path(ellipseIn: plaque), with: .color(theme.cellBackground))
        let letter = Text(kind == .xSum ? "X" : "V")
            .font(.system(size: cellSize * 0.26, weight: .semibold, design: .rounded))
            .foregroundColor(theme.givenText)
        context.draw(context.resolve(letter), at: edge.mid, anchor: .center)
    }

    /// A thick bar along the shared edge.
    private static func drawBar(
        _ context: GraphicsContext,
        edge: EdgeGeometry,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        var bar = Path()
        let half = cellSize * 0.28
        if edge.horizontalPair {
            bar.move(to: CGPoint(x: edge.mid.x, y: edge.mid.y - half))
            bar.addLine(to: CGPoint(x: edge.mid.x, y: edge.mid.y + half))
        } else {
            bar.move(to: CGPoint(x: edge.mid.x - half, y: edge.mid.y))
            bar.addLine(to: CGPoint(x: edge.mid.x + half, y: edge.mid.y))
        }
        context.stroke(
            bar,
            with: .color(theme.givenText),
            style: StrokeStyle(lineWidth: cellSize * 0.09, lineCap: .round),
        )
    }

    /// Chevron apex points at the smaller cell (b), like ">".
    private static func drawChevron(
        _ context: GraphicsContext,
        edge: EdgeGeometry,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        let mid = edge.mid
        let plaqueRadius = cellSize * 0.16
        context.fill(
            Path(ellipseIn: CGRect(
                x: mid.x - plaqueRadius,
                y: mid.y - plaqueRadius,
                width: plaqueRadius * 2,
                height: plaqueRadius * 2,
            )),
            with: .color(theme.cellBackground),
        )
        let arm = cellSize * 0.11
        let towardB = CGVector(
            dx: (edge.centerB.x - edge.centerA.x).sign(),
            dy: (edge.centerB.y - edge.centerA.y).sign(),
        )
        var chevron = Path()
        let apex = CGPoint(x: mid.x + towardB.dx * arm, y: mid.y + towardB.dy * arm)
        if edge.horizontalPair {
            chevron.move(to: CGPoint(x: mid.x - towardB.dx * arm, y: mid.y - arm))
            chevron.addLine(to: apex)
            chevron.addLine(to: CGPoint(x: mid.x - towardB.dx * arm, y: mid.y + arm))
        } else {
            chevron.move(to: CGPoint(x: mid.x - arm, y: mid.y - towardB.dy * arm))
            chevron.addLine(to: apex)
            chevron.addLine(to: CGPoint(x: mid.x + arm, y: mid.y - towardB.dy * arm))
        }
        context.stroke(
            chevron,
            with: .color(theme.givenText),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round),
        )
    }
}

private extension CGFloat {
    func sign() -> CGFloat {
        self > 0 ? 1 : (self < 0 ? -1 : 0)
    }
}
