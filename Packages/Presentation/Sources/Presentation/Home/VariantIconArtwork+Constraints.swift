import Model
import SwiftUI

/// Catalog-tile artwork for the constraint variants: cages, diagonals,
/// windows, parity, movement bans, edge marks, lines, and outside clues.
extension VariantIconArtwork {
    static func killer(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        // A dashed cage across the top two boxes, sum clue inside it.
        let cage = cellRect(row: 0, col: 1, rowSpan: 1, colSpan: 2, grid: 3, in: rect)
            .insetBy(dx: 2, dy: 2)
        let dash = StrokeStyle(lineWidth: 1, dash: [3, 2.2])
        context.stroke(
            Path(roundedRect: cage, cornerRadius: 2),
            with: .color(theme.accent),
            style: dash,
        )
        let sum = Text("15")
            .font(.system(size: rect.height * 0.19, weight: .semibold))
            .foregroundColor(theme.accent)
        context.draw(
            context.resolve(sum),
            at: CGPoint(x: cage.minX + cage.width * 0.22, y: cage.midY),
        )
    }

    static func diagonal(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        var main = Path()
        main.move(to: CGPoint(x: rect.minX, y: rect.minY))
        main.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        var anti = Path()
        anti.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        anti.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        for path in [main, anti] {
            context.stroke(path, with: .color(theme.accent), lineWidth: 1.6)
        }
    }

    static func windoku(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        // Windows first so grid lines stay visible above the tint.
        for (row, col) in [(1, 1), (1, 5), (5, 1), (5, 5)] {
            let window = cellRect(row: row, col: col, rowSpan: 3, colSpan: 3, grid: 9, in: rect)
            context.fill(Path(window), with: .color(theme.accent.opacity(0.3)))
        }
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
    }

    static func evenOdd(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        let circleCell = cellRect(row: 2, col: 2, grid: 9, in: rect).insetBy(dx: 0.5, dy: 0.5)
        context.fill(Path(ellipseIn: circleCell), with: .color(theme.accent.opacity(0.85)))
        let squareCell = cellRect(row: 5, col: 6, grid: 9, in: rect).insetBy(dx: 0.7, dy: 0.7)
        context.fill(
            Path(roundedRect: squareCell, cornerRadius: 1),
            with: .color(theme.accent.opacity(0.45)),
        )
    }

    static func argyle(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        var lines = Path()
        // The X.
        lines.move(to: point(0, 0, in: rect))
        lines.addLine(to: point(1, 1, in: rect))
        lines.move(to: point(1, 0, in: rect))
        lines.addLine(to: point(0, 1, in: rect))
        // The inscribed diamond.
        lines.move(to: point(0.5, 0, in: rect))
        lines.addLine(to: point(1, 0.5, in: rect))
        lines.addLine(to: point(0.5, 1, in: rect))
        lines.addLine(to: point(0, 0.5, in: rect))
        lines.closeSubpath()
        context.stroke(lines, with: .color(theme.accent), lineWidth: 1.3)
    }

    static func asterisk(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        for (row, col) in [(1, 4), (4, 1), (4, 4), (4, 7), (7, 4)] {
            let cell = cellRect(row: row, col: col, grid: 9, in: rect).insetBy(dx: 0.4, dy: 0.4)
            context.fill(Path(ellipseIn: cell), with: .color(theme.accent.opacity(0.85)))
        }
    }

    static func antiKnight(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        // A filled cell, an L-shaped move, and the forbidden landing square.
        let origin = cellRect(row: 4, col: 2, grid: 9, in: rect)
        context.fill(
            Path(ellipseIn: origin.insetBy(dx: 0.3, dy: 0.3)),
            with: .color(theme.accent),
        )
        var move = Path()
        move.move(to: CGPoint(x: origin.midX, y: origin.midY))
        let corner = cellRect(row: 2, col: 2, grid: 9, in: rect)
        move.addLine(to: CGPoint(x: corner.midX, y: corner.midY))
        let landing = cellRect(row: 2, col: 3, grid: 9, in: rect)
        move.addLine(to: CGPoint(x: landing.midX, y: landing.midY))
        context.stroke(
            move,
            with: .color(theme.accent.opacity(0.7)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round),
        )
        context.stroke(
            Path(ellipseIn: landing.insetBy(dx: 0.3, dy: 0.3)),
            with: .color(theme.accent),
            lineWidth: 1,
        )
    }

    static func antiKing(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        let center = cellRect(row: 4, col: 4, grid: 9, in: rect)
        context.fill(
            Path(ellipseIn: center.insetBy(dx: 0.3, dy: 0.3)),
            with: .color(theme.accent),
        )
        for (dr, dc) in [(-2, -2), (-2, 2), (2, -2), (2, 2)] {
            let cell = cellRect(row: 4 + dr / 2, col: 4 + dc / 2, grid: 9, in: rect)
            context.stroke(
                Path(ellipseIn: cell.insetBy(dx: 0.5, dy: 0.5)),
                with: .color(theme.accent.opacity(0.7)),
                lineWidth: 1,
            )
        }
    }

    /// A coarse 3×3 sketch with two symbol marks on cell borders, for the
    /// XV and greater-than tiles.
    static func edgeMarks(
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
        symbols: [String],
    ) {
        grid(3, boldEvery: nil, in: rect, context: &context, theme: theme)
        let spots = [
            CGPoint(x: rect.minX + rect.width / 3, y: rect.minY + rect.height / 6),
            CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 2 / 3),
        ]
        for (symbol, spot) in zip(symbols, spots) {
            let text = Text(symbol)
                .font(.system(size: rect.height * 0.24, weight: .bold, design: .rounded))
                .foregroundColor(theme.accent)
            context.draw(context.resolve(text), at: spot, anchor: .center)
        }
    }

    static func kropki(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(3, boldEvery: nil, in: rect, context: &context, theme: theme)
        let radius = rect.width * 0.07
        let spots: [(position: CGPoint, filled: Bool)] = [
            (CGPoint(x: 1 / 3, y: 1 / 6), false),
            (CGPoint(x: 2 / 3, y: 0.5), true),
            (CGPoint(x: 1 / 6, y: 2 / 3), false),
        ]
        for spot in spots {
            let dot = CGRect(
                x: rect.minX + rect.width * spot.position.x - radius,
                y: rect.minY + rect.height * spot.position.y - radius,
                width: radius * 2,
                height: radius * 2,
            )
            if spot.filled {
                context.fill(Path(ellipseIn: dot), with: .color(theme.accent))
            } else {
                context.fill(Path(ellipseIn: dot), with: .color(theme.cellBackground))
                context.stroke(Path(ellipseIn: dot), with: .color(theme.accent), lineWidth: 1.2)
            }
        }
    }

    static func consecutiveBars(
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
    ) {
        grid(3, boldEvery: nil, in: rect, context: &context, theme: theme)
        var bars = Path()
        let third = rect.width / 3
        bars.move(to: CGPoint(x: rect.minX + third, y: rect.minY + third * 0.25))
        bars.addLine(to: CGPoint(x: rect.minX + third, y: rect.minY + third * 0.75))
        bars.move(to: CGPoint(x: rect.minX + third * 1.25, y: rect.minY + third * 2))
        bars.addLine(to: CGPoint(x: rect.minX + third * 1.75, y: rect.minY + third * 2))
        context.stroke(
            bars,
            with: .color(theme.accent),
            style: StrokeStyle(lineWidth: 3, lineCap: .round),
        )
    }

    static func miracle(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        // A near-empty board with a lone given and a sparkle: the "no clues
        // at all" fantasy.
        let lone = cellRect(row: 6, col: 2, grid: 9, in: rect)
        context.fill(
            Path(ellipseIn: lone.insetBy(dx: 0.3, dy: 0.3)),
            with: .color(theme.accent),
        )
        let sparkle = Text("✦")
            .font(.system(size: rect.height * 0.34))
            .foregroundColor(theme.accent)
        context.draw(
            context.resolve(sparkle),
            at: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.midY - rect.height * 0.12),
            anchor: .center,
        )
    }

    static func thermo(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        // Bulb bottom-left, stem rising to the upper right.
        let bulb = point(0.22, 0.78, in: rect)
        var stem = Path()
        stem.move(to: bulb)
        stem.addLine(to: point(0.22, 0.4, in: rect))
        stem.addLine(to: point(0.6, 0.4, in: rect))
        stem.addLine(to: point(0.6, 0.18, in: rect))
        context.stroke(
            stem,
            with: .color(theme.accent.opacity(0.55)),
            style: StrokeStyle(lineWidth: rect.width * 0.14, lineCap: .round, lineJoin: .round),
        )
        let radius = rect.width * 0.13
        context.fill(
            Path(ellipseIn: CGRect(
                x: bulb.x - radius,
                y: bulb.y - radius,
                width: radius * 2,
                height: radius * 2,
            )),
            with: .color(theme.accent),
        )
    }

    static func arrow(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        let circleCenter = point(0.26, 0.26, in: rect)
        let radius = rect.width * 0.14
        context.stroke(
            Path(ellipseIn: CGRect(
                x: circleCenter.x - radius,
                y: circleCenter.y - radius,
                width: radius * 2,
                height: radius * 2,
            )),
            with: .color(theme.accent),
            lineWidth: 1.4,
        )
        var shaft = Path()
        shaft.move(to: point(0.36, 0.36, in: rect))
        shaft.addLine(to: point(0.74, 0.74, in: rect))
        shaft.move(to: point(0.74, 0.74, in: rect))
        shaft.addLine(to: point(0.74, 0.52, in: rect))
        shaft.move(to: point(0.74, 0.74, in: rect))
        shaft.addLine(to: point(0.52, 0.74, in: rect))
        context.stroke(
            shaft,
            with: .color(theme.accent),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round),
        )
    }

    /// A smaller inset grid with clue numbers hovering outside its edge.
    static func outside(
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
        labels: [String],
    ) {
        let inner = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.16)
            .offsetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
        grid(9, boldEvery: 3, in: inner, context: &context, theme: theme)
        let spots = [
            CGPoint(x: rect.minX + rect.width * 0.02, y: inner.minY + inner.height * 0.17),
            CGPoint(x: inner.minX + inner.width * 0.5, y: rect.minY + rect.height * 0.02),
        ]
        for (label, spot) in zip(labels, spots) {
            let text = Text(label)
                .font(.system(size: rect.height * 0.2, weight: .semibold, design: .rounded))
                .foregroundColor(theme.accent)
            context.draw(context.resolve(text), at: spot, anchor: .topLeading)
        }
    }

    static func littleKiller(
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
    ) {
        let inner = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.16)
            .offsetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)
        grid(9, boldEvery: 3, in: inner, context: &context, theme: theme)
        let label = Text("21")
            .font(.system(size: rect.height * 0.19, weight: .semibold, design: .rounded))
            .foregroundColor(theme.accent)
        context.draw(
            context.resolve(label),
            at: CGPoint(x: rect.minX, y: rect.minY),
            anchor: .topLeading,
        )
        var arrowPath = Path()
        arrowPath.move(to: point(0.16, 0.16, in: rect))
        arrowPath.addLine(to: point(0.4, 0.4, in: rect))
        arrowPath.move(to: point(0.4, 0.4, in: rect))
        arrowPath.addLine(to: point(0.4, 0.28, in: rect))
        arrowPath.move(to: point(0.4, 0.4, in: rect))
        arrowPath.addLine(to: point(0.28, 0.4, in: rect))
        context.stroke(
            arrowPath,
            with: .color(theme.accent),
            style: StrokeStyle(lineWidth: 1.3, lineCap: .round),
        )
    }

    static func fogOfWar(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        fillCells(
            [(2, 2), (6, 5)],
            grid: 9,
            in: rect,
            context: &context,
            color: theme.accent.opacity(0.85),
        )
        // A soft fog bank rolling over the far side.
        var fog = Path()
        fog.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.45,
            y: rect.minY - rect.height * 0.1,
            width: rect.width * 0.75,
            height: rect.height * 0.62,
        ))
        fog.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.62,
            y: rect.minY + rect.height * 0.35,
            width: rect.width * 0.6,
            height: rect.height * 0.55,
        ))
        context.fill(fog, with: .color(theme.gridLineBold.opacity(0.4)))
    }

    static func killerGT(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        let cage = cellRect(row: 0, col: 1, rowSpan: 1, colSpan: 2, grid: 3, in: rect)
            .insetBy(dx: 2, dy: 2)
        context.stroke(
            Path(roundedRect: cage, cornerRadius: 2),
            with: .color(theme.accent),
            style: StrokeStyle(lineWidth: 1, dash: [3, 2.2]),
        )
        let mark = Text("›")
            .font(.system(size: rect.height * 0.3, weight: .bold, design: .rounded))
            .foregroundColor(theme.accent)
        context.draw(
            context.resolve(mark),
            at: CGPoint(x: cage.midX, y: cage.midY),
            anchor: .center,
        )
    }
}
