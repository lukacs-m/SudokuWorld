import Model
import SwiftUI

/// The illustrated tile on a catalog card: a miniature grid sketch with a
/// variant-specific decoration, drawn programmatically so every theme and
/// color scheme renders it correctly.
struct VariantIconView: View {
    let variant: SudokuVariant
    let theme: Theme

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
            VariantIconArtwork.draw(variant, in: rect, context: &context, theme: theme)
        }
        .background(theme.cellBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.gridLineBold.opacity(0.45), lineWidth: 1),
        )
        .accessibilityHidden(true)
    }
}

/// Pure drawing code for the catalog tiles. Exhaustive over `SudokuVariant`
/// on purpose: adding a case without artwork must not compile.
enum VariantIconArtwork {
    static func draw(
        _ variant: SudokuVariant,
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
    ) {
        switch variant {
        case .classic: classic(in: rect, context: &context, theme: theme)
        case .mini4: mini(in: rect, context: &context, theme: theme, size: 4, label: "4×4")
        case .mini6: mini(in: rect, context: &context, theme: theme, size: 6, label: "6×6")
        case .dodeka12: sized(
                in: rect,
                context: &context,
                theme: theme,
                size: 12,
                boldEvery: nil,
                label: "12",
            )
        case .hexadoku16: sized(
                in: rect,
                context: &context,
                theme: theme,
                size: 16,
                boldEvery: 4,
                label: "0–F",
            )
        case .alphadoku25: sized(
                in: rect,
                context: &context,
                theme: theme,
                size: 25,
                boldEvery: 5,
                label: "A–Y",
            )
        case .killer: killer(in: rect, context: &context, theme: theme)
        case .diagonal: diagonal(in: rect, context: &context, theme: theme)
        case .windoku: windoku(in: rect, context: &context, theme: theme)
        case .evenOdd: evenOdd(in: rect, context: &context, theme: theme)
        case .samurai: multiGrid(
                origins: [(0, 0), (0, 12), (6, 6), (12, 0), (12, 12)],
                span: (21, 21), in: rect, context: &context, theme: theme,
            )
        case .gattai2: multiGrid(
                origins: [(0, 0), (6, 6)],
                span: (15, 15), in: rect, context: &context, theme: theme,
            )
        case .gattai3: multiGrid(
                origins: [(0, 0), (6, 6), (12, 12)],
                span: (21, 21), in: rect, context: &context, theme: theme,
            )
        case .gattai8: multiGrid(
                origins: [
                    (0, 0),
                    (0, 12),
                    (0, 24),
                    (6, 6),
                    (6, 18),
                    (12, 0),
                    (12, 12),
                    (12, 24),
                ],
                span: (21, 33), in: rect, context: &context, theme: theme,
            )
        case .shogun: multiGrid(
                origins: [
                    (0, 0),
                    (0, 12),
                    (0, 24),
                    (0, 36),
                    (6, 6),
                    (6, 18),
                    (6, 30),
                    (12, 0),
                    (12, 12),
                    (12, 24),
                    (12, 36),
                ],
                span: (21, 45), in: rect, context: &context, theme: theme,
            )
        case .sumo: multiGrid(
                origins: [
                    (0, 0),
                    (0, 12),
                    (0, 24),
                    (6, 6),
                    (6, 18),
                    (12, 0),
                    (12, 12),
                    (12, 24),
                    (18, 6),
                    (18, 18),
                    (24, 0),
                    (24, 12),
                    (24, 24),
                ],
                span: (33, 33), in: rect, context: &context, theme: theme,
            )
        case .wordoku: wordoku(in: rect, context: &context, theme: theme)
        case .jigsaw: jigsaw(in: rect, context: &context, theme: theme)
        case .argyle: argyle(in: rect, context: &context, theme: theme)
        case .asterisk: asterisk(in: rect, context: &context, theme: theme)
        case .antiKnight: antiKnight(in: rect, context: &context, theme: theme)
        case .antiKing: antiKing(in: rect, context: &context, theme: theme)
        case .greaterThan: edgeMarks(in: rect, context: &context, theme: theme, symbols: ["‹", "›"])
        case .kropki: kropki(in: rect, context: &context, theme: theme)
        case .xv: edgeMarks(in: rect, context: &context, theme: theme, symbols: ["X", "V"])
        case .consecutive: consecutiveBars(in: rect, context: &context, theme: theme)
        case .miracle: miracle(in: rect, context: &context, theme: theme)
        }
    }

    // MARK: - Variant artwork

    private static func classic(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        fillCells(
            [(1, 2), (4, 6), (6, 1)],
            grid: 9,
            in: rect,
            context: &context,
            color: theme.accent.opacity(0.85),
        )
    }

    private static func mini(
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
        size: Int,
        label: String,
    ) {
        grid(size, boldEvery: nil, in: rect, context: &context, theme: theme)
        let text = Text(label)
            .font(.system(size: rect.height * 0.32, weight: .semibold, design: .serif))
            .foregroundColor(theme.accent)
        context.draw(
            context.resolve(text),
            at: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.maxY - rect.height * 0.18),
        )
    }

    /// A dense grid with a corner label on a soft plaque, for the big sizes.
    private static func sized(
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
        size: Int,
        boldEvery: Int?,
        label: String,
    ) {
        grid(size, boldEvery: boldEvery, in: rect, context: &context, theme: theme)
        let plaque = CGRect(
            x: rect.maxX - rect.width * 0.52,
            y: rect.maxY - rect.height * 0.34,
            width: rect.width * 0.52,
            height: rect.height * 0.34,
        )
        context.fill(Path(roundedRect: plaque, cornerRadius: 2), with: .color(theme.cellBackground))
        let text = Text(label)
            .font(.system(size: rect.height * 0.26, weight: .semibold, design: .serif))
            .foregroundColor(theme.accent)
        context.draw(context.resolve(text), at: CGPoint(x: plaque.midX, y: plaque.midY))
    }

    private static func wordoku(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        for (glyph, row, col) in [("A", 0, 1), ("E", 4, 4), ("I", 7, 6)] {
            let cell = cellRect(row: row, col: col, rowSpan: 2, colSpan: 2, grid: 9, in: rect)
            let text = Text(glyph)
                .font(.system(size: rect.height * 0.22, weight: .semibold, design: .serif))
                .foregroundColor(theme.accent)
            context.draw(context.resolve(text), at: CGPoint(x: cell.midX, y: cell.midY))
        }
    }

    private static func killer(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
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

    private static func diagonal(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
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

    private static func windoku(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        // Windows first so grid lines stay visible above the tint.
        for (row, col) in [(1, 1), (1, 5), (5, 1), (5, 5)] {
            let window = cellRect(row: row, col: col, rowSpan: 3, colSpan: 3, grid: 9, in: rect)
            context.fill(Path(window), with: .color(theme.accent.opacity(0.3)))
        }
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
    }

    private static func evenOdd(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        let circleCell = cellRect(row: 2, col: 2, grid: 9, in: rect).insetBy(dx: 0.5, dy: 0.5)
        context.fill(Path(ellipseIn: circleCell), with: .color(theme.accent.opacity(0.85)))
        let squareCell = cellRect(row: 5, col: 6, grid: 9, in: rect).insetBy(dx: 0.7, dy: 0.7)
        context.fill(
            Path(roundedRect: squareCell, cornerRadius: 1),
            with: .color(theme.accent.opacity(0.45)),
        )
    }

    /// A true miniature of an overlapping-grid layout: each 9×9 sub-grid is
    /// a stroked square, centers (row offset 6 or 18) tinted.
    private static func multiGrid(
        origins: [(Int, Int)],
        span: (rows: Int, cols: Int),
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
    ) {
        let scale = min(
            rect.width / CGFloat(span.cols),
            rect.height / CGFloat(span.rows),
        )
        let side = 9 * scale
        let originX = rect.midX - CGFloat(span.cols) * scale / 2
        let originY = rect.midY - CGFloat(span.rows) * scale / 2
        for (row, col) in origins where row % 12 == 6 {
            let square = CGRect(
                x: originX + CGFloat(col) * scale,
                y: originY + CGFloat(row) * scale,
                width: side,
                height: side,
            )
            context.fill(Path(square), with: .color(theme.accent.opacity(0.3)))
        }
        for (row, col) in origins {
            let square = CGRect(
                x: originX + CGFloat(col) * scale,
                y: originY + CGFloat(row) * scale,
                width: side,
                height: side,
            )
            context.stroke(Path(square), with: .color(theme.gridLineBold), lineWidth: 1)
        }
    }

    private static func jigsaw(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        // Two interlocking organic regions, like the mock: no grid, just the
        // suggestion of wonky pieces.
        var upper = Path()
        upper.move(to: point(0.18, 0.30, in: rect))
        upper.addLine(to: point(0.52, 0.18, in: rect))
        upper.addLine(to: point(0.66, 0.44, in: rect))
        upper.addLine(to: point(0.40, 0.46, in: rect))
        upper.addLine(to: point(0.32, 0.62, in: rect))
        upper.closeSubpath()
        var lower = Path()
        lower.move(to: point(0.44, 0.56, in: rect))
        lower.addLine(to: point(0.82, 0.46, in: rect))
        lower.addLine(to: point(0.88, 0.74, in: rect))
        lower.addLine(to: point(0.54, 0.84, in: rect))
        lower.closeSubpath()
        context.fill(upper, with: .color(theme.accent.opacity(0.45)))
        context.stroke(upper, with: .color(theme.gridLineBold), lineWidth: 1)
        context.fill(lower, with: .color(theme.cellBackgroundAlternate))
        context.stroke(lower, with: .color(theme.gridLineBold), lineWidth: 1)
    }

    private static func argyle(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
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

    private static func asterisk(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        for (row, col) in [(1, 4), (4, 1), (4, 4), (4, 7), (7, 4)] {
            let cell = cellRect(row: row, col: col, grid: 9, in: rect).insetBy(dx: 0.4, dy: 0.4)
            context.fill(Path(ellipseIn: cell), with: .color(theme.accent.opacity(0.85)))
        }
    }

    private static func antiKnight(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
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

    private static func antiKing(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
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
    private static func edgeMarks(
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

    private static func kropki(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(3, boldEvery: nil, in: rect, context: &context, theme: theme)
        let radius = rect.width * 0.07
        let spots: [(CGFloat, CGFloat, Bool)] = [
            (1 / 3, 1 / 6, false), (2 / 3, 0.5, true), (1 / 6, 2 / 3, false),
        ]
        for (x, y, filled) in spots {
            let dot = CGRect(
                x: rect.minX + rect.width * x - radius,
                y: rect.minY + rect.height * y - radius,
                width: radius * 2,
                height: radius * 2,
            )
            if filled {
                context.fill(Path(ellipseIn: dot), with: .color(theme.accent))
            } else {
                context.fill(Path(ellipseIn: dot), with: .color(theme.cellBackground))
                context.stroke(Path(ellipseIn: dot), with: .color(theme.accent), lineWidth: 1.2)
            }
        }
    }

    private static func consecutiveBars(
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

    private static func miracle(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
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

    private static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }

    // MARK: - Shared sketch helpers

    /// Interior grid lines for an `n`×`n` sketch; every `boldEvery`-th line
    /// is drawn in the bold grid color.
    static func grid(
        _ n: Int,
        boldEvery: Int?,
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
    ) {
        let step = rect.width / CGFloat(n)
        for line in 1 ..< n {
            let bold = boldEvery.map { line % $0 == 0 } ?? false
            let color = bold ? theme.gridLineBold : theme.gridLine
            let x = rect.minX + CGFloat(line) * step
            var vertical = Path()
            vertical.move(to: CGPoint(x: x, y: rect.minY))
            vertical.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.stroke(vertical, with: .color(color), lineWidth: bold ? 1 : 0.5)

            let y = rect.minY + CGFloat(line) * (rect.height / CGFloat(n))
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: rect.minX, y: y))
            horizontal.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.stroke(horizontal, with: .color(color), lineWidth: bold ? 1 : 0.5)
        }
        context.stroke(Path(rect), with: .color(theme.gridLineBold), lineWidth: 1)
    }

    /// The rect covering a block of sketch cells.
    static func cellRect(
        row: Int,
        col: Int,
        rowSpan: Int = 1,
        colSpan: Int = 1,
        grid n: Int,
        in rect: CGRect,
    ) -> CGRect {
        let cellWidth = rect.width / CGFloat(n)
        let cellHeight = rect.height / CGFloat(n)
        return CGRect(
            x: rect.minX + CGFloat(col) * cellWidth,
            y: rect.minY + CGFloat(row) * cellHeight,
            width: cellWidth * CGFloat(colSpan),
            height: cellHeight * CGFloat(rowSpan),
        )
    }

    static func fillCells(
        _ cells: [(row: Int, col: Int)],
        grid n: Int,
        in rect: CGRect,
        context: inout GraphicsContext,
        color: Color,
    ) {
        for cell in cells {
            let target = cellRect(row: cell.row, col: cell.col, grid: n, in: rect)
                .insetBy(dx: 1, dy: 1)
            context.fill(Path(roundedRect: target, cornerRadius: 1), with: .color(color))
        }
    }
}
