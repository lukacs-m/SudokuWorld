import Model
import SwiftUI

/// Draws thermometer and arrow shapes under the digits: a thermometer is a
/// bulb plus a thick rounded path, an arrow a circled cell with a shaft and
/// head. Both trace cell centers, so any topology renders correctly.
enum LineOverlay {
    static func draw(
        _ context: GraphicsContext,
        thermometers: [[Int]],
        arrows: [Arrow],
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) {
        let lineColor = theme.gridLineBold.opacity(0.35)

        for path in thermometers {
            guard let bulb = path.first else { continue }
            var stem = Path()
            stem.move(to: BoardDecorations.cellCenter(bulb, topology: topology, cellSize: cellSize))
            for cell in path.dropFirst() {
                stem.addLine(to: BoardDecorations.cellCenter(
                    cell,
                    topology: topology,
                    cellSize: cellSize,
                ))
            }
            context.stroke(
                stem,
                with: .color(lineColor),
                style: StrokeStyle(
                    lineWidth: cellSize * 0.30,
                    lineCap: .round,
                    lineJoin: .round,
                ),
            )
            let center = BoardDecorations.cellCenter(bulb, topology: topology, cellSize: cellSize)
            let radius = cellSize * 0.34
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2,
                )),
                with: .color(lineColor),
            )
        }

        for arrow in arrows {
            let circleCenter = BoardDecorations.cellCenter(
                arrow.circle,
                topology: topology,
                cellSize: cellSize,
            )
            let radius = cellSize * 0.38
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: circleCenter.x - radius,
                    y: circleCenter.y - radius,
                    width: radius * 2,
                    height: radius * 2,
                )),
                with: .color(theme.gridLineBold.opacity(0.7)),
                lineWidth: 1.5,
            )
            guard let first = arrow.shaft.first, let last = arrow.shaft.last else { continue }

            var shaft = Path()
            let firstCenter = BoardDecorations.cellCenter(
                first,
                topology: topology,
                cellSize: cellSize,
            )
            // Start on the circle's rim, not its center.
            let dx = firstCenter.x - circleCenter.x
            let dy = firstCenter.y - circleCenter.y
            let length = max(1, (dx * dx + dy * dy).squareRoot())
            shaft.move(to: CGPoint(
                x: circleCenter.x + dx / length * radius,
                y: circleCenter.y + dy / length * radius,
            ))
            for cell in arrow.shaft {
                shaft.addLine(to: BoardDecorations.cellCenter(
                    cell,
                    topology: topology,
                    cellSize: cellSize,
                ))
            }
            context.stroke(
                shaft,
                with: .color(theme.gridLineBold.opacity(0.7)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round),
            )

            // Arrowhead at the shaft's end, oriented along the last segment.
            let lastCenter = BoardDecorations.cellCenter(
                last,
                topology: topology,
                cellSize: cellSize,
            )
            let previous = arrow.shaft.count > 1
                ? BoardDecorations.cellCenter(
                    arrow.shaft[arrow.shaft.count - 2],
                    topology: topology,
                    cellSize: cellSize,
                )
                : circleCenter
            let angle = atan2(lastCenter.y - previous.y, lastCenter.x - previous.x)
            let head = cellSize * 0.22
            var arrowhead = Path()
            for side in [angle + .pi * 0.78, angle - .pi * 0.78] {
                arrowhead.move(to: lastCenter)
                arrowhead.addLine(to: CGPoint(
                    x: lastCenter.x + cos(side) * head,
                    y: lastCenter.y + sin(side) * head,
                ))
            }
            context.stroke(
                arrowhead,
                with: .color(theme.gridLineBold.opacity(0.7)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round),
            )
        }
    }
}
