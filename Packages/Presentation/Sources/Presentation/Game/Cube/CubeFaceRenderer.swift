import CoreGraphics
import CoreText
import Domain
import Foundation
import Model
import SwiftUI
#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

/// Everything one cube face shows, as plain values. Faces are textured
/// quads: a face re-renders only when its snapshot changes, and the digits
/// stay crisp because the texture is drawn at `CubeFaceRenderer.pixels`
/// per side rather than scaled from a smaller image.
nonisolated struct CubeFaceSnapshot: Equatable, Sendable {
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

    /// The theme's board colors resolved to components, so the renderer
    /// can draw them off the main actor.
    struct Palette: Equatable, Sendable {
        let cellBackground: Color.Resolved
        let gridLine: Color.Resolved
        let gridLineBold: Color.Resolved
        let givenText: Color.Resolved
        let playerText: Color.Resolved
        let noteText: Color.Resolved
        let selection: Color.Resolved
        let relatedHighlight: Color.Resolved
        let sameDigitHighlight: Color.Resolved
        let conflict: Color.Resolved
        let hintHighlight: Color.Resolved

        init(theme: Theme) {
            let environment = EnvironmentValues()
            cellBackground = theme.cellBackground.resolve(in: environment)
            gridLine = theme.gridLine.resolve(in: environment)
            gridLineBold = theme.gridLineBold.resolve(in: environment)
            givenText = theme.givenText.resolve(in: environment)
            playerText = theme.playerText.resolve(in: environment)
            noteText = theme.noteText.resolve(in: environment)
            selection = theme.selection.resolve(in: environment)
            relatedHighlight = theme.relatedHighlight.resolve(in: environment)
            sameDigitHighlight = theme.sameDigitHighlight.resolve(in: environment)
            conflict = theme.conflict.resolve(in: environment)
            hintHighlight = theme.hintHighlight.resolve(in: environment)
        }
    }

    let cells: [Cell]
    let palette: Palette

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
        palette: Palette,
    ) -> Self {
        let faceCells = (0 ..< CubeNet.cellsPerFace).map { offset in
            let index = CubeNet.index(face: face, row: offset / 3, col: offset % 3)
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
        return Self(cells: faceCells, palette: palette)
    }
}

/// Draws a face snapshot into a square bitmap with the flat board's visual
/// language: base fill, highlight layers, digits, notes, grid lines. Pure
/// CoreGraphics and CoreText so it can run off the main actor; a tap must
/// never wait on a texture.
nonisolated enum CubeFaceRenderer {
    static let pixels = 768

    @concurrent
    static func render(_ snapshot: CubeFaceSnapshot) async -> CGImage? {
        guard !Task.isCancelled else { return nil }
        return draw(snapshot)
    }

    static func draw(_ snapshot: CubeFaceSnapshot) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return nil }
        let side = CGFloat(pixels)
        // Flip to y-down so cells and text sit exactly where the flat board puts them.
        context.translateBy(x: 0, y: side)
        context.scaleBy(x: 1, y: -1)

        let palette = snapshot.palette
        let cellSize = side / 3
        let givenFont = font(size: cellSize * 0.55, semibold: true)
        let playerFont = font(size: cellSize * 0.55, semibold: false)
        let noteFont = font(size: cellSize * 0.24, semibold: false)
        context.setFillColor(palette.cellBackground.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))

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
                fill(rect, with: palette.relatedHighlight, in: context)
            }
            if cell.isSameDigit {
                fill(rect, with: palette.sameDigitHighlight, in: context)
            }
            if cell.isHint {
                fill(rect, with: palette.hintHighlight, in: context)
            }
            if cell.isConflict {
                fill(rect, with: palette.conflict, opacity: 0.18, in: context)
            }
            if cell.isSelected {
                fill(rect, with: palette.selection, in: context)
            }
            if let value = cell.value {
                drawValue(
                    value,
                    cell: cell,
                    in: rect,
                    font: cell.isGiven ? givenFont : playerFont,
                    context: context,
                    palette: palette,
                )
            } else {
                drawNotes(cell.notes, in: rect, font: noteFont, context: context, palette: palette)
            }
        }

        drawGrid(context: context, side: side, cellSize: cellSize, palette: palette)
        return context.makeImage()
    }

    private static func fill(
        _ rect: CGRect,
        with color: Color.Resolved,
        opacity: Float = 1,
        in context: CGContext,
    ) {
        var color = color
        color.opacity *= opacity
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    private static func drawValue(
        _ value: Int,
        cell: CubeFaceSnapshot.Cell,
        in rect: CGRect,
        font: CTFont,
        context: CGContext,
        palette: CubeFaceSnapshot.Palette,
    ) {
        let color = if cell.isWrong {
            palette.conflict
        } else if cell.isGiven {
            palette.givenText
        } else {
            palette.playerText
        }
        draw(
            VariantGlyphs.glyph(value, for: .cube),
            font: font,
            color: color,
            at: CGPoint(x: rect.midX, y: rect.midY),
            in: context,
        )
    }

    private static func drawNotes(
        _ notes: [Int],
        in rect: CGRect,
        font: CTFont,
        context: CGContext,
        palette: CubeFaceSnapshot.Palette,
    ) {
        let columns = VariantGlyphs.noteColumns(forSize: 9)
        for digit in notes where digit <= 9 {
            let column = (digit - 1) % columns
            let row = (digit - 1) / columns
            let point = CGPoint(
                x: rect.minX + rect.width * (CGFloat(column) + 0.5) / CGFloat(columns),
                y: rect.minY + rect.height * (CGFloat(row) + 0.5) / CGFloat(columns),
            )
            draw(
                VariantGlyphs.glyph(digit, for: .cube),
                font: font,
                color: palette.noteText,
                at: point,
                in: context,
            )
        }
    }

    /// The flat board's `.system(size:weight:design: .rounded)`.
    private static func font(size: CGFloat, semibold: Bool) -> CTFont {
        #if canImport(UIKit)
            let base = UIFont.systemFont(ofSize: size, weight: semibold ? .semibold : .regular)
            let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size) as CTFont
        #else
            let base = NSFont.systemFont(ofSize: size, weight: semibold ? .semibold : .regular)
            let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
            return (NSFont(descriptor: descriptor, size: size) ?? base) as CTFont
        #endif
    }

    /// Centres the line's typographic box on `center`, as
    /// `GraphicsContext.draw(_:at:anchor: .center)` does on the flat board.
    private static func draw(
        _ string: String,
        font: CTFont,
        color: Color.Resolved,
        at center: CGPoint,
        in context: CGContext,
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .init(kCTFontAttributeName as String): font,
            .init(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        // Glyphs are drawn upright in the flipped context.
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(
            x: center.x - width / 2,
            y: center.y + (ascent - descent) / 2,
        )
        CTLineDraw(line, context)
    }

    private static func drawGrid(
        context: CGContext,
        side: CGFloat,
        cellSize: CGFloat,
        palette: CubeFaceSnapshot.Palette,
    ) {
        context.setStrokeColor(palette.gridLine.cgColor)
        context.setLineWidth(side * 0.004)
        for line in 1 ..< 3 {
            let offset = CGFloat(line) * cellSize
            context.move(to: CGPoint(x: offset, y: 0))
            context.addLine(to: CGPoint(x: offset, y: side))
            context.move(to: CGPoint(x: 0, y: offset))
            context.addLine(to: CGPoint(x: side, y: offset))
        }
        context.strokePath()
        // The face border is the cube's edge: bold, drawn inset so it
        // survives texture sampling at the quad's rim.
        let border = side * 0.012
        let rim = CGRect(x: 0, y: 0, width: side, height: side)
            .insetBy(dx: border / 2, dy: border / 2)
        context.setStrokeColor(palette.gridLineBold.cgColor)
        context.setLineWidth(border)
        context.stroke(rim)
    }
}
