import Model
import SwiftUI

/// Draws relation marks on the shared edge between two adjacent cells:
/// kropki dots, XV letters, consecutive bars, and futoshiki inequality
/// chevrons. Drawn above the grid lines so the marks sit on them.
enum EdgeMarkOverlay {
    static func draw(
        _ context: GraphicsContext,
        relations: [RelationClue],
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        for clue in relations {
            let centerA = BoardDecorations.cellCenter(
                clue.a,
                topology: topology,
                cellSize: cellSize,
            )
            let centerB = BoardDecorations.cellCenter(
                clue.b,
                topology: topology,
                cellSize: cellSize,
            )
            let mid = CGPoint(x: (centerA.x + centerB.x) / 2, y: (centerA.y + centerB.y) / 2)
            let horizontalPair = abs(centerA.y - centerB.y) < 0.5

            switch clue.kind {
            case .whiteDot, .blackDot:
                let radius = cellSize * 0.14
                let dot = CGRect(
                    x: mid.x - radius,
                    y: mid.y - radius,
                    width: radius * 2,
                    height: radius * 2,
                )
                context.fill(
                    Path(ellipseIn: dot),
                    with: .color(clue.kind == .blackDot ? theme.givenText : theme.cellBackground),
                )
                context.stroke(
                    Path(ellipseIn: dot),
                    with: .color(theme.givenText),
                    lineWidth: 1,
                )

            case .xSum, .vSum:
                let radius = cellSize * 0.17
                let plaque = CGRect(
                    x: mid.x - radius,
                    y: mid.y - radius,
                    width: radius * 2,
                    height: radius * 2,
                )
                context.fill(Path(ellipseIn: plaque), with: .color(theme.cellBackground))
                let letter = Text(clue.kind == .xSum ? "X" : "V")
                    .font(.system(size: cellSize * 0.26, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.givenText)
                context.draw(context.resolve(letter), at: mid, anchor: .center)

            case .consecutive:
                // A thick bar along the shared edge.
                var bar = Path()
                let half = cellSize * 0.28
                if horizontalPair {
                    bar.move(to: CGPoint(x: mid.x, y: mid.y - half))
                    bar.addLine(to: CGPoint(x: mid.x, y: mid.y + half))
                } else {
                    bar.move(to: CGPoint(x: mid.x - half, y: mid.y))
                    bar.addLine(to: CGPoint(x: mid.x + half, y: mid.y))
                }
                context.stroke(
                    bar,
                    with: .color(theme.givenText),
                    style: StrokeStyle(lineWidth: cellSize * 0.09, lineCap: .round),
                )

            case .greaterThan:
                // Chevron apex points at the smaller cell (b), like ">".
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
                    dx: (centerB.x - centerA.x).sign(),
                    dy: (centerB.y - centerA.y).sign(),
                )
                var chevron = Path()
                let apex = CGPoint(x: mid.x + towardB.dx * arm, y: mid.y + towardB.dy * arm)
                if horizontalPair {
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
    }
}

private extension CGFloat {
    func sign() -> CGFloat {
        self > 0 ? 1 : (self < 0 ? -1 : 0)
    }
}
