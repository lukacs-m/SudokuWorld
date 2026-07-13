import Domain
import Foundation
import Model
import SwiftUI

/// The playing surface. One Canvas draws everything (shading, highlights,
/// cages, digits, notes, grid), and a transparent per-cell layer on top
/// provides tap targets and VoiceOver access. Entirely topology-driven, so
/// classic, mini, killer, diagonal, windoku, even-odd, and samurai all render
/// through this single view.
struct BoardView: View {
    let viewModel: GameViewModel

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let session = viewModel.session, let topology = viewModel.topology {
            let theme = themeStore.theme(for: colorScheme)
            GeometryReader { proxy in
                let cellSize = min(
                    proxy.size.width / CGFloat(topology.colCount),
                    proxy.size.height / CGFloat(topology.rowCount),
                )
                let boardWidth = cellSize * CGFloat(topology.colCount)
                let boardHeight = cellSize * CGFloat(topology.rowCount)

                ZStack(alignment: .topLeading) {
                    boardCanvas(
                        session: session,
                        topology: topology,
                        theme: theme,
                        cellSize: cellSize,
                    )
                    tapLayer(session: session, topology: topology, cellSize: cellSize)
                }
                .frame(width: boardWidth, height: boardHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(
                CGFloat(topology.colCount) / CGFloat(topology.rowCount),
                contentMode: .fit,
            )
        }
    }

    private func boardCanvas(
        session: GameSession,
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
    ) -> some View {
        // Snapshot observable state outside the canvas closure.
        let selected = viewModel.selectedCell
        let related = viewModel.relatedCells
        let sameDigit = viewModel.sameDigitCells
        let conflicts = viewModel.conflicts
        let hintCells = Set(viewModel.presentedHint?.cells ?? [])
        let settings = viewModel.settings

        return Canvas { context, _ in
            // Inactive positions (samurai corners) stay transparent; active
            // cells get the base fill.
            for index in 0 ..< topology.cellCount {
                context.fill(
                    Path(BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)),
                    with: .color(theme.cellBackground),
                )
            }
            BoardDecorations.drawShading(
                context,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
            )
            BoardDecorations.drawDiagonals(
                context,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
            )
            LineOverlay.draw(
                context,
                thermometers: session.puzzle.thermometers,
                arrows: session.puzzle.arrows,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
            )

            // Highlights, back to front: related, same digit, hint, selection.
            for index in related {
                fill(context, index, topology, cellSize, theme.relatedHighlight)
            }
            for index in sameDigit {
                fill(context, index, topology, cellSize, theme.sameDigitHighlight)
            }
            for index in hintCells {
                fill(context, index, topology, cellSize, theme.hintHighlight)
            }
            if settings.autoCheck {
                for index in conflicts {
                    fill(context, index, topology, cellSize, theme.conflict.opacity(0.18))
                }
            }
            if let selected {
                fill(context, selected, topology, cellSize, theme.selection)
            }

            BoardDecorations.drawParityMarks(
                context,
                parities: session.puzzle.parities,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
            )
            CageOverlay.draw(
                context,
                cages: session.puzzle.cages,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
            )
            drawDigits(
                context,
                session: session,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
                settings: settings,
            )
            BoardDecorations.drawGridLines(
                context,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
            )
            EdgeMarkOverlay.draw(
                context,
                relations: session.puzzle.relations,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
            )
        }
    }

    private func fill(
        _ context: GraphicsContext,
        _ index: Int,
        _ topology: GridTopology,
        _ cellSize: CGFloat,
        _ color: Color,
    ) {
        context.fill(
            Path(BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)),
            with: .color(color),
        )
    }

    private func drawDigits(
        _ context: GraphicsContext,
        session: GameSession,
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
        settings: GameSettings,
    ) {
        let variant = session.puzzle.variant
        let noteColumns = VariantGlyphs.noteColumns(forSize: topology.size)
        let noteRows = (topology.size + noteColumns - 1) / noteColumns

        for index in 0 ..< session.board.count {
            let cell = session.board[index]
            let center = BoardDecorations.cellCenter(index, topology: topology, cellSize: cellSize)

            if let value = cell.value {
                let isWrong = !cell.isGiven && value != session.puzzle.solution[index]
                let color: Color = if isWrong, settings.mistakeHighlighting {
                    theme.conflict
                } else if cell.isGiven {
                    theme.givenText
                } else {
                    theme.playerText
                }
                let glyph = VariantGlyphs.glyph(value, for: variant)
                // Two-character values (10–16 on big grids) need a smaller face.
                let text = Text(glyph)
                    .font(.system(
                        size: cellSize * (glyph.count > 1 ? 0.44 : 0.55),
                        weight: cell.isGiven ? .semibold : .regular,
                        design: .rounded,
                    ))
                    .foregroundStyle(color)
                context.draw(context.resolve(text), at: center, anchor: .center)
            } else if !cell.notes.isEmpty {
                let rect = BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)
                for digit in cell.notes.digits where digit <= topology.size {
                    let column = (digit - 1) % noteColumns
                    let row = (digit - 1) / noteColumns
                    let point = CGPoint(
                        x: rect.minX + cellSize * (CGFloat(column) + 0.5) / CGFloat(noteColumns),
                        y: rect.minY + cellSize * (CGFloat(row) + 0.5) / CGFloat(noteRows),
                    )
                    let glyph = VariantGlyphs.glyph(digit, for: variant)
                    let text = Text(glyph)
                        .font(.system(
                            size: cellSize * (glyph.count > 1 ? 0.19 : 0.24),
                            design: .rounded,
                        ))
                        .foregroundStyle(theme.noteText)
                    context.draw(context.resolve(text), at: point, anchor: .center)
                }
            }
        }
    }

    private func tapLayer(
        session: GameSession,
        topology: GridTopology,
        cellSize: CGFloat,
    ) -> some View {
        ForEach(0 ..< topology.cellCount, id: \.self) { index in
            let rect = BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .onTapGesture { viewModel.tapCell(index) }
                .accessibilityLabel(GameAccessibility.cellLabel(
                    index: index,
                    board: session.board,
                    puzzle: session.puzzle,
                    topology: topology,
                ))
                .accessibilityAddTraits(
                    viewModel.selectedCell == index ? [.isButton, .isSelected] : .isButton,
                )
        }
    }
}
