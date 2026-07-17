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

/// Pure drawing code for the catalog tiles. The per-variant artwork lives in
/// the `VariantIconArtwork+Grids` and `VariantIconArtwork+Constraints`
/// extensions; this file keeps the dispatch and the shared sketch helpers.
enum VariantIconArtwork {
    // Exhaustive over `SudokuVariant` on purpose: adding a case without
    // artwork must not compile.
    // swiftlint:disable:next cyclomatic_complexity
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
        case .dodeka12:
            sized(in: rect, context: &context, theme: theme, size: 12, boldEvery: nil, label: "12")
        case .hexadoku16:
            sized(in: rect, context: &context, theme: theme, size: 16, boldEvery: 4, label: "0–F")
        case .alphadoku25:
            sized(in: rect, context: &context, theme: theme, size: 25, boldEvery: 5, label: "A–Y")
        case .killer: killer(in: rect, context: &context, theme: theme)
        case .diagonal: diagonal(in: rect, context: &context, theme: theme)
        case .windoku: windoku(in: rect, context: &context, theme: theme)
        case .evenOdd: evenOdd(in: rect, context: &context, theme: theme)
        case .samurai: samurai(in: rect, context: &context, theme: theme)
        case .gattai2: gattai2(in: rect, context: &context, theme: theme)
        case .gattai3: gattai3(in: rect, context: &context, theme: theme)
        case .gattai8: gattai8(in: rect, context: &context, theme: theme)
        case .shogun: shogun(in: rect, context: &context, theme: theme)
        case .sumo: sumo(in: rect, context: &context, theme: theme)
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
        case .thermo: thermo(in: rect, context: &context, theme: theme)
        case .arrow: arrow(in: rect, context: &context, theme: theme)
        case .sandwich: outside(in: rect, context: &context, theme: theme, labels: ["17", "4"])
        case .skyscraper: outside(in: rect, context: &context, theme: theme, labels: ["3", "1"])
        case .littleKiller: littleKiller(in: rect, context: &context, theme: theme)
        case .fogOfWar: fogOfWar(in: rect, context: &context, theme: theme)
        case .killerGT: killerGT(in: rect, context: &context, theme: theme)
        case .tredoku: tredoku(in: rect, context: &context, theme: theme)
        }
    }

    // MARK: - Shared sketch helpers

    /// Interior grid lines for a `cellsPerSide`² sketch; every
    /// `boldEvery`-th line is drawn in the bold grid color.
    static func grid(
        _ cellsPerSide: Int,
        boldEvery: Int?,
        in rect: CGRect,
        context: inout GraphicsContext,
        theme: Theme,
    ) {
        let step = rect.width / CGFloat(cellsPerSide)
        for line in 1 ..< cellsPerSide {
            let bold = boldEvery.map { line.isMultiple(of: $0) } ?? false
            let color = bold ? theme.gridLineBold : theme.gridLine
            let x = rect.minX + CGFloat(line) * step
            var vertical = Path()
            vertical.move(to: CGPoint(x: x, y: rect.minY))
            vertical.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.stroke(vertical, with: .color(color), lineWidth: bold ? 1 : 0.5)

            let y = rect.minY + CGFloat(line) * (rect.height / CGFloat(cellsPerSide))
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
        grid cellsPerSide: Int,
        in rect: CGRect,
    ) -> CGRect {
        let cellWidth = rect.width / CGFloat(cellsPerSide)
        let cellHeight = rect.height / CGFloat(cellsPerSide)
        return CGRect(
            x: rect.minX + CGFloat(col) * cellWidth,
            y: rect.minY + CGFloat(row) * cellHeight,
            width: cellWidth * CGFloat(colSpan),
            height: cellHeight * CGFloat(rowSpan),
        )
    }

    static func fillCells(
        _ cells: [(row: Int, col: Int)],
        grid cellsPerSide: Int,
        in rect: CGRect,
        context: inout GraphicsContext,
        color: Color,
    ) {
        for cell in cells {
            let target = cellRect(row: cell.row, col: cell.col, grid: cellsPerSide, in: rect)
                .insetBy(dx: 1, dy: 1)
            context.fill(Path(roundedRect: target, cornerRadius: 1), with: .color(color))
        }
    }

    static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }
}
