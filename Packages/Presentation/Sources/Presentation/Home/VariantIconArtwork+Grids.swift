import Model
import SwiftUI

/// Catalog-tile artwork for the grid-shaped variants: classic, the sized
/// boards, the overlapping-grid family, wordoku, jigsaw, tredoku, and the cube.
extension VariantIconArtwork {
    static func classic(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        fillCells(
            [(1, 2), (4, 6), (6, 1)],
            grid: 9,
            in: rect,
            context: &context,
            color: theme.accent.opacity(0.85),
        )
    }

    static func mini(
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
    static func sized(
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

    // MARK: - Overlapping-grid family

    static func samurai(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        multiGrid(
            origins: samuraiOrigins,
            span: (21, 21),
            in: rect,
            context: &context,
            theme: theme,
        )
    }

    static func gattai2(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        multiGrid(
            origins: gattai2Origins,
            span: (15, 15),
            in: rect,
            context: &context,
            theme: theme,
        )
    }

    static func gattai3(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        multiGrid(
            origins: gattai3Origins,
            span: (21, 21),
            in: rect,
            context: &context,
            theme: theme,
        )
    }

    static func gattai8(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        multiGrid(
            origins: gattai8Origins,
            span: (21, 33),
            in: rect,
            context: &context,
            theme: theme,
        )
    }

    static func shogun(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        multiGrid(
            origins: shogunOrigins,
            span: (21, 45),
            in: rect,
            context: &context,
            theme: theme,
        )
    }

    static func sumo(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        multiGrid(
            origins: sumoOrigins,
            span: (33, 33),
            in: rect,
            context: &context,
            theme: theme,
        )
    }

    private static let samuraiOrigins: [(Int, Int)] = [
        (0, 0), (0, 12), (6, 6), (12, 0), (12, 12),
    ]

    private static let gattai2Origins: [(Int, Int)] = [(0, 0), (6, 6)]

    private static let gattai3Origins: [(Int, Int)] = [(0, 0), (6, 6), (12, 12)]

    private static let gattai8Origins: [(Int, Int)] = [
        (0, 0), (0, 12), (0, 24), (6, 6),
        (6, 18), (12, 0), (12, 12), (12, 24),
    ]

    private static let shogunOrigins: [(Int, Int)] = [
        (0, 0), (0, 12), (0, 24), (0, 36), (6, 6), (6, 18),
        (6, 30), (12, 0), (12, 12), (12, 24), (12, 36),
    ]

    private static let sumoOrigins: [(Int, Int)] = [
        (0, 0), (0, 12), (0, 24), (6, 6), (6, 18), (12, 0), (12, 12),
        (12, 24), (18, 6), (18, 18), (24, 0), (24, 12), (24, 24),
    ]

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

    // MARK: - Other grid shapes

    static func wordoku(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        grid(9, boldEvery: 3, in: rect, context: &context, theme: theme)
        let glyphs: [(glyph: String, cell: (row: Int, col: Int))] = [
            ("A", (0, 1)), ("E", (4, 4)), ("I", (7, 6)),
        ]
        for entry in glyphs {
            let cell = cellRect(
                row: entry.cell.row,
                col: entry.cell.col,
                rowSpan: 2,
                colSpan: 2,
                grid: 9,
                in: rect,
            )
            let text = Text(entry.glyph)
                .font(.system(size: rect.height * 0.22, weight: .semibold, design: .serif))
                .foregroundColor(theme.accent)
            context.draw(context.resolve(text), at: CGPoint(x: cell.midX, y: cell.midY))
        }
    }

    static func jigsaw(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
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

    static func tredoku(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        // An isometric cube corner: top rhombus and two visible faces.
        let cx = rect.midX
        let cy = rect.midY
        let width = rect.width * 0.42
        let height = rect.height * 0.24
        let top = CGPoint(x: cx, y: cy - height * 2)
        let left = CGPoint(x: cx - width, y: cy - height)
        let right = CGPoint(x: cx + width, y: cy - height)
        let center = CGPoint(x: cx, y: cy)
        let bottomLeft = CGPoint(x: cx - width, y: cy + height)
        let bottomRight = CGPoint(x: cx + width, y: cy + height)
        let bottom = CGPoint(x: cx, y: cy + height * 2)

        var topFace = Path()
        topFace.move(to: top)
        topFace.addLine(to: right)
        topFace.addLine(to: center)
        topFace.addLine(to: left)
        topFace.closeSubpath()
        var leftFace = Path()
        leftFace.move(to: left)
        leftFace.addLine(to: center)
        leftFace.addLine(to: bottom)
        leftFace.addLine(to: bottomLeft)
        leftFace.closeSubpath()
        var rightFace = Path()
        rightFace.move(to: center)
        rightFace.addLine(to: right)
        rightFace.addLine(to: bottomRight)
        rightFace.addLine(to: bottom)
        rightFace.closeSubpath()

        context.fill(topFace, with: .color(theme.accent.opacity(0.45)))
        context.fill(leftFace, with: .color(theme.accent.opacity(0.25)))
        context.fill(rightFace, with: .color(theme.cellBackgroundAlternate))
        for face in [topFace, leftFace, rightFace] {
            context.stroke(face, with: .color(theme.gridLineBold), lineWidth: 1)
        }
    }

    static func cube(in rect: CGRect, context: inout GraphicsContext, theme: Theme) {
        // A whole isometric cube, each visible face ruled into 3×3 cells.
        let cx = rect.midX
        let cy = rect.midY
        let width = rect.width * 0.42
        let height = rect.height * 0.24
        let top = CGPoint(x: cx, y: cy - height * 2)
        let left = CGPoint(x: cx - width, y: cy - height)
        let right = CGPoint(x: cx + width, y: cy - height)
        let center = CGPoint(x: cx, y: cy)
        let bottomLeft = CGPoint(x: cx - width, y: cy + height)
        let bottomRight = CGPoint(x: cx + width, y: cy + height)
        let bottom = CGPoint(x: cx, y: cy + height * 2)

        let faces: [(corners: [CGPoint], fill: Color)] = [
            ([top, right, center, left], theme.cellBackgroundAlternate),
            ([left, center, bottom, bottomLeft], theme.accent.opacity(0.28)),
            ([center, right, bottomRight, bottom], theme.accent.opacity(0.5)),
        ]
        for face in faces {
            var outline = Path()
            outline.addLines(face.corners)
            outline.closeSubpath()
            context.fill(outline, with: .color(face.fill))
            // Interior rulings join thirds of opposite edges.
            var rulings = Path()
            let corners = face.corners
            for third in [1.0 / 3.0, 2.0 / 3.0] {
                rulings.move(to: lerp(corners[0], corners[1], third))
                rulings.addLine(to: lerp(corners[3], corners[2], third))
                rulings.move(to: lerp(corners[0], corners[3], third))
                rulings.addLine(to: lerp(corners[1], corners[2], third))
            }
            context.stroke(rulings, with: .color(theme.gridLine), lineWidth: 0.5)
            context.stroke(outline, with: .color(theme.gridLineBold), lineWidth: 1)
        }
    }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, _ fraction: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
    }
}
