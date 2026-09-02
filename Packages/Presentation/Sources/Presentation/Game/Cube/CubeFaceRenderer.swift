import CoreGraphics
import Domain
import Model
import SwiftUI

/// Everything one cube face shows, as plain values. Faces are textured
/// quads: a face re-renders only when its snapshot changes, and the digits
/// stay crisp because the texture is drawn at `CubeFaceRenderer.pixels`
/// per side rather than scaled from a smaller image.
struct CubeFaceSnapshot: Equatable, Sendable {
    struct Cell: Equatable, Sendable {
        var value: Int?
        var isGiven = false
        var notes: [Int] = []
        var isWrong = false
        var isRelated = false
        var isSameDigit = false
        var isHint = false
        var isConflict = false
        var isSelected = false
    }

    let cells: [Cell]
    let theme: Theme

    // swiftlint:disable:next function_parameter_count
    static func make(
        face: CubeNet.Face,
        session: GameSession,
        selected: Int?,
        related: Set<Int>,
        sameDigit: Set<Int>,
        conflicts: Set<Int>,
        hintCells: Set<Int>,
        settings: GameSettings,
        theme: Theme,
    ) -> Self {
        let faceCells = (0 ..< CubeNet.cellsPerFace).map { offset in
            let index = face.rawValue * CubeNet.cellsPerFace + offset
            let cell = session.board[index]
            let isWrong = settings.mistakeHighlighting
                && !cell.isGiven
                && cell.value.map { $0 != session.puzzle.solution[index] } ?? false
            return Cell(
                value: cell.value,
                isGiven: cell.isGiven,
                notes: cell.value == nil ? cell.notes.digits : [],
                isWrong: isWrong,
                isRelated: related.contains(index),
                isSameDigit: sameDigit.contains(index),
                isHint: hintCells.contains(index),
                isConflict: settings.autoCheck && conflicts.contains(index),
                isSelected: selected == index,
            )
        }
        return Self(cells: faceCells, theme: theme)
    }
}

/// Draws a face snapshot into a square bitmap with the flat board's visual
/// language: base fill, highlight layers, digits, notes, grid lines.
enum CubeFaceRenderer {
    static let pixels = 768

    @MainActor
    static func render(_ snapshot: CubeFaceSnapshot) -> CGImage? {
        let side = CGFloat(pixels)
        let renderer = ImageRenderer(content: Canvas { context, _ in
            draw(snapshot, into: context, side: side)
        }
        .frame(width: side, height: side))
        renderer.scale = 1
        return renderer.cgImage
    }

    static func draw(_ snapshot: CubeFaceSnapshot, into context: GraphicsContext, side: CGFloat) {
        let theme = snapshot.theme
        let cellSize = side / 3
        let square = CGRect(x: 0, y: 0, width: side, height: side)
        context.fill(Path(square), with: .color(theme.cellBackground))

        for (offset, cell) in snapshot.cells.enumerated() {
            let rect = CGRect(
                x: CGFloat(offset % 3) * cellSize,
                y: CGFloat(offset / 3) * cellSize,
                width: cellSize,
                height: cellSize,
            )
            // Same stacking order as the flat board: related, same digit,
            // hint, conflict, selection.
            if cell.isRelated {
                context.fill(Path(rect), with: .color(theme.relatedHighlight))
            }
            if cell.isSameDigit {
                context.fill(Path(rect), with: .color(theme.sameDigitHighlight))
            }
            if cell.isHint {
                context.fill(Path(rect), with: .color(theme.hintHighlight))
            }
            if cell.isConflict {
                context.fill(Path(rect), with: .color(theme.conflict.opacity(0.18)))
            }
            if cell.isSelected {
                context.fill(Path(rect), with: .color(theme.selection))
            }
            if let value = cell.value {
                drawValue(value, cell: cell, in: rect, context: context, theme: theme)
            } else {
                drawNotes(cell.notes, in: rect, context: context, theme: theme)
            }
        }

        drawGrid(context: context, side: side, cellSize: cellSize, theme: theme)
    }

    private static func drawValue(
        _ value: Int,
        cell: CubeFaceSnapshot.Cell,
        in rect: CGRect,
        context: GraphicsContext,
        theme: Theme,
    ) {
        let color: Color = if cell.isWrong {
            theme.conflict
        } else if cell.isGiven {
            theme.givenText
        } else {
            theme.playerText
        }
        let text = Text(VariantGlyphs.glyph(value, for: .cube))
            .font(.system(
                size: rect.width * 0.55,
                weight: cell.isGiven ? .semibold : .regular,
                design: .rounded,
            ))
            .foregroundStyle(color)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.draw(context.resolve(text), at: center, anchor: .center)
    }

    private static func drawNotes(
        _ notes: [Int],
        in rect: CGRect,
        context: GraphicsContext,
        theme: Theme,
    ) {
        let columns = VariantGlyphs.noteColumns(forSize: 9)
        for digit in notes where digit <= 9 {
            let column = (digit - 1) % columns
            let row = (digit - 1) / columns
            let point = CGPoint(
                x: rect.minX + rect.width * (CGFloat(column) + 0.5) / CGFloat(columns),
                y: rect.minY + rect.height * (CGFloat(row) + 0.5) / CGFloat(columns),
            )
            let text = Text(VariantGlyphs.glyph(digit, for: .cube))
                .font(.system(size: rect.width * 0.24, design: .rounded))
                .foregroundStyle(theme.noteText)
            context.draw(context.resolve(text), at: point, anchor: .center)
        }
    }

    private static func drawGrid(
        context: GraphicsContext,
        side: CGFloat,
        cellSize: CGFloat,
        theme: Theme,
    ) {
        var inner = Path()
        for line in 1 ..< 3 {
            let offset = CGFloat(line) * cellSize
            inner.move(to: CGPoint(x: offset, y: 0))
            inner.addLine(to: CGPoint(x: offset, y: side))
            inner.move(to: CGPoint(x: 0, y: offset))
            inner.addLine(to: CGPoint(x: side, y: offset))
        }
        context.stroke(inner, with: .color(theme.gridLine), lineWidth: side * 0.004)
        // The face border is the cube's edge: bold, drawn inset so it
        // survives texture sampling at the quad's rim.
        let border = side * 0.012
        let rim = CGRect(x: 0, y: 0, width: side, height: side)
            .insetBy(dx: border / 2, dy: border / 2)
        context.stroke(Path(rim), with: .color(theme.gridLineBold), lineWidth: border)
    }
}
