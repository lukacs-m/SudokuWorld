import Domain
import Foundation
import Model
import SwiftUI

/// The read-only mini-board of a lesson: the figure's givens and pencil
/// marks, the pattern's cells shaded, and the step it yields — a placed
/// digit, or candidates struck through. Drawn with the live board's own
/// layers so it follows every theme.
struct LessonFigureView: View {
    let figure: TechniqueFigure

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let topology = TopologyFactory.topology(for: figure.variant)
        // Outside clues reserve a one-cell gutter around the grid.
        let gutterCells: CGFloat = figure.outsideClues.isEmpty ? 0 : 2
        let columns = CGFloat(topology.colCount) + gutterCells
        let rows = CGFloat(topology.rowCount) + gutterCells
        Canvas { context, size in
            let cellSize = size.width / columns
            let renderer = LessonFigureRenderer(
                figure: figure,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
                gutter: cellSize * gutterCells / 2,
            )
            renderer.draw(context)
        }
        .aspectRatio(columns / rows, contentMode: .fit)
        .accessibilityLabel(Text(verbatim: figure.technique.lessonText("figure")))
        .accessibilityAddTraits(.isImage)
    }
}

private struct LessonFigureRenderer {
    let figure: TechniqueFigure
    let topology: GridTopology
    let theme: Theme
    let cellSize: CGFloat
    let gutter: CGFloat

    func draw(_ context: GraphicsContext) {
        if gutter > 0 {
            OutsideClueOverlay.draw(
                context,
                clues: figure.outsideClues,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
                gutter: gutter,
            )
        }
        var context = context
        context.translateBy(x: gutter, y: gutter)

        for index in 0 ..< topology.cellCount {
            fill(context, index, theme.cellBackground)
        }
        BoardDecorations.drawShading(context, topology: topology, theme: theme, cellSize: cellSize)
        LineOverlay.draw(
            context,
            puzzle: linePuzzle,
            topology: topology,
            theme: theme,
            cellSize: cellSize,
        )
        for index in Set(figure.regionCells) {
            fill(context, index, theme.relatedHighlight)
        }
        for index in figure.focusCells {
            fill(context, index, theme.hintHighlight)
        }
        CageOverlay.draw(
            context,
            cages: figure.cages,
            topology: topology,
            theme: theme,
            cellSize: cellSize,
        )
        drawDigits(context)
        drawNotes(context)
        BoardDecorations.drawGridLines(
            context,
            topology: topology,
            theme: theme,
            cellSize: cellSize,
        )
        EdgeMarkOverlay.draw(
            context,
            relations: figure.relations,
            topology: topology,
            theme: theme,
            cellSize: cellSize,
        )
    }

    /// `LineOverlay` reads arrows off a puzzle; only the arrows matter here.
    private var linePuzzle: PuzzleDefinition {
        PuzzleDefinition(
            id: UUID(),
            variant: figure.variant,
            requestedDifficulty: .easy,
            gradedDifficulty: .easy,
            seed: 0,
            givens: [Int?](repeating: nil, count: topology.cellCount),
            solution: [Int](repeating: 0, count: topology.cellCount),
            arrows: figure.arrows,
        )
    }

    private func fill(_ context: GraphicsContext, _ index: Int, _ color: Color) {
        context.fill(
            Path(BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)),
            with: .color(color),
        )
    }

    private func drawDigits(_ context: GraphicsContext) {
        for (index, digit) in figure.givens {
            drawValue(context, digit, at: index, color: theme.givenText, weight: .semibold)
        }
        if let placement = figure.placement {
            drawValue(
                context,
                placement.digit,
                at: placement.index,
                color: theme.playerText,
                weight: .regular,
            )
        }
    }

    private func drawValue(
        _ context: GraphicsContext,
        _ digit: Int,
        at index: Int,
        color: Color,
        weight: Font.Weight,
    ) {
        let center = BoardDecorations.cellCenter(index, topology: topology, cellSize: cellSize)
        let text = Text(VariantGlyphs.glyph(digit, for: figure.variant))
            .font(.system(size: cellSize * 0.55, weight: weight, design: .rounded))
            .foregroundStyle(color)
        context.draw(context.resolve(text), at: center, anchor: .center)
    }

    /// Declared pencil marks in the note colour; eliminated candidates in the
    /// conflict colour with a strike through, whether or not the cell
    /// declares other marks.
    private func drawNotes(_ context: GraphicsContext) {
        var struck: [Int: Set<Int>] = [:]
        for elimination in figure.eliminations {
            struck[elimination.index, default: []].insert(elimination.digit)
        }
        let cells = Set(figure.candidates.keys).union(struck.keys)
        for index in cells {
            let rect = BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)
            let digits = Set(figure.candidates[index] ?? []).union(struck[index] ?? [])
            for digit in digits {
                let point = BoardDecorations.notePoint(for: digit, in: rect, size: topology.size)
                let isStruck = struck[index]?.contains(digit) == true
                let text = Text(VariantGlyphs.glyph(digit, for: figure.variant))
                    .font(.system(size: cellSize * 0.27, design: .rounded))
                    .foregroundStyle(isStruck ? theme.conflict : theme.noteText)
                context.draw(context.resolve(text), at: point, anchor: .center)
                guard isStruck else { continue }
                var strike = Path()
                strike.move(to: CGPoint(x: point.x - cellSize * 0.1, y: point.y))
                strike.addLine(to: CGPoint(x: point.x + cellSize * 0.1, y: point.y))
                context.stroke(strike, with: .color(theme.conflict), lineWidth: 1.2)
            }
        }
    }
}
