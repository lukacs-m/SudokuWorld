import Domain
import Foundation
import Model
import SwiftUI

/// The playing surface. One Canvas draws everything (shading, highlights,
/// cages, digits, notes, grid), and a transparent per-cell layer on top
/// provides VoiceOver access; taps land on the container and map through the
/// zoom transform. Pinch zooms and drag pans the board within its slot.
/// Entirely topology-driven, so classic, mini, killer, diagonal, windoku,
/// even-odd, and samurai all render through this single view.
struct BoardView: View {
    let viewModel: GameViewModel

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var zoom = BoardZoom()
    @GestureState private var pinch: (magnification: CGFloat, start: CGPoint)?
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        if let session = viewModel.session, let topology = viewModel.topology {
            let theme = themeStore.theme(for: colorScheme)
            // Outside clues (sandwich/skyscraper/little killer) reserve a
            // one-cell gutter around the grid for their labels.
            let gutterCells: CGFloat = session.puzzle.outsideClues.isEmpty ? 0 : 2
            GeometryReader { proxy in
                let baseCell = min(
                    proxy.size.width / (CGFloat(topology.colCount) + gutterCells),
                    proxy.size.height / (CGFloat(topology.rowCount) + gutterCells),
                )
                let base = CGSize(
                    width: baseCell * (CGFloat(topology.colCount) + gutterCells),
                    height: baseCell * (CGFloat(topology.rowCount) + gutterCells),
                )
                let maxScale = BoardZoom.maxScale(rows: topology.rowCount, cols: topology.colCount)
                let display = displayZoom(base: base, maxScale: maxScale)
                // The board re-renders at the zoomed cell size (rather than
                // scaling the drawn output) so digits stay crisp.
                let cellSize = baseCell * display.scale
                let gutter = cellSize * gutterCells / 2

                // Not a button: the per-cell layer carries the VoiceOver
                // button semantics; the container tap is plain hit testing.
                // swiftlint:disable:next accessibility_trait_for_button
                ZStack(alignment: .topLeading) {
                    boardCanvas(
                        session: session,
                        topology: topology,
                        theme: theme,
                        cellSize: cellSize,
                        gutter: gutter,
                    )
                    // Accessibility-only: .clipped() below does not clip hit
                    // testing, so zoomed cells must not be tappable — the
                    // container tap plus inverse math handles touch instead.
                    tapLayer(session: session, topology: topology, cellSize: cellSize)
                        .offset(x: gutter, y: gutter)
                        .allowsHitTesting(false)
                }
                .frame(width: base.width * display.scale, height: base.height * display.scale)
                .offset(display.offset)
                .frame(width: base.width, height: base.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    magnify(base: base, maxScale: maxScale)
                        .simultaneously(with: pan(base: base, maxScale: maxScale)),
                )
                .onTapGesture { location in
                    tapCell(
                        at: location,
                        base: base,
                        baseCell: baseCell,
                        gutterCells: gutterCells,
                        maxScale: maxScale,
                        topology: topology,
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(
                (CGFloat(topology.colCount) + gutterCells)
                    / (CGFloat(topology.rowCount) + gutterCells),
                contentMode: .fit,
            )
        }
    }

    /// Committed zoom plus any in-flight pinch/drag, run through the same
    /// clamped math the gesture commits use, so live and committed state
    /// cannot drift.
    private func displayZoom(base: CGSize, maxScale: CGFloat) -> BoardZoom {
        var display = zoom
        if let pinch {
            display = display.zoomed(
                by: pinch.magnification,
                about: CGPoint(
                    x: pinch.start.x - base.width / 2,
                    y: pinch.start.y - base.height / 2,
                ),
                base: base,
                maxScale: maxScale,
            )
        }
        return display.panned(by: drag, base: base, maxScale: maxScale)
    }

    private func magnify(base: CGSize, maxScale: CGFloat) -> some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in
                state = (value.magnification, value.startLocation)
            }
            .onEnded { value in
                zoom = zoom.zoomed(
                    by: value.magnification,
                    about: CGPoint(
                        x: value.startLocation.x - base.width / 2,
                        y: value.startLocation.y - base.height / 2,
                    ),
                    base: base,
                    maxScale: maxScale,
                )
            }
    }

    private func pan(base: CGSize, maxScale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($drag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                zoom = zoom.panned(by: value.translation, base: base, maxScale: maxScale)
            }
    }

    private func tapCell(
        at location: CGPoint,
        base: CGSize,
        baseCell: CGFloat,
        gutterCells: CGFloat,
        maxScale: CGFloat,
        topology: GridTopology,
    ) {
        let point = displayZoom(base: base, maxScale: maxScale).boardPoint(location, base: base)
        let gutter = baseCell * gutterCells / 2
        let row = Int(((point.y - gutter) / baseCell).rounded(.down))
        let col = Int(((point.x - gutter) / baseCell).rounded(.down))
        guard let index = topology.index(row: row, col: col) else { return }
        viewModel.tapCell(index)
    }

    private func boardCanvas(
        session: GameSession,
        topology: GridTopology,
        theme: Theme,
        cellSize: CGFloat,
        gutter: CGFloat,
    ) -> some View {
        // Snapshot observable state outside the canvas closure.
        let renderer = BoardRenderer(
            session: session,
            topology: topology,
            theme: theme,
            cellSize: cellSize,
            gutter: gutter,
            selected: viewModel.selectedCell,
            related: viewModel.relatedCells,
            sameDigit: viewModel.sameDigitCells,
            conflicts: viewModel.conflicts,
            hintCells: Set(viewModel.presentedHint?.cells ?? []),
            settings: viewModel.settings,
        )
        return Canvas { context, _ in
            renderer.draw(context)
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
                .accessibilityAction { viewModel.tapCell(index) }
                .accessibilityLabel(GameAccessibility.cellLabel(
                    index: index,
                    board: session.board,
                    puzzle: session.puzzle,
                    topology: topology,
                    fogged: session.isFogged(index),
                ))
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(viewModel.selectedCell == index ? .isSelected : [])
        }
    }
}

/// Immutable snapshot of everything one frame of the board needs, with the
/// drawing pass split into layers. Lives outside the view so the Canvas
/// closure captures plain values, not observable state.
private struct BoardRenderer {
    let session: GameSession
    let topology: GridTopology
    let theme: Theme
    let cellSize: CGFloat
    let gutter: CGFloat
    let selected: Int?
    let related: Set<Int>
    let sameDigit: Set<Int>
    let conflicts: Set<Int>
    let hintCells: Set<Int>
    let settings: GameSettings

    func draw(_ context: GraphicsContext) {
        if gutter > 0 {
            OutsideClueOverlay.draw(
                context,
                clues: session.puzzle.outsideClues,
                topology: topology,
                theme: theme,
                cellSize: cellSize,
                gutter: gutter,
            )
        }
        var context = context
        context.translateBy(x: gutter, y: gutter)
        drawBase(context)
        drawHighlights(context)
        drawMarksAndDigits(context)
    }

    /// Base fills, shading, diagonals, and line shapes under everything.
    /// Inactive positions (samurai corners) stay transparent; active cells
    /// get the base fill.
    private func drawBase(_ context: GraphicsContext) {
        for index in 0 ..< topology.cellCount {
            fill(context, index, theme.cellBackground)
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
            puzzle: session.puzzle,
            topology: topology,
            theme: theme,
            cellSize: cellSize,
        )
    }

    /// Highlights, back to front: related, same digit, hint, selection.
    private func drawHighlights(_ context: GraphicsContext) {
        for index in related {
            fill(context, index, theme.relatedHighlight)
        }
        for index in sameDigit {
            fill(context, index, theme.sameDigitHighlight)
        }
        for index in hintCells {
            fill(context, index, theme.hintHighlight)
        }
        if settings.autoCheck {
            for index in conflicts {
                fill(context, index, theme.conflict.opacity(0.18))
            }
        }
        if let selected {
            fill(context, selected, theme.selection)
        }
    }

    private func drawMarksAndDigits(_ context: GraphicsContext) {
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
        drawDigits(context)
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

    private func fill(_ context: GraphicsContext, _ index: Int, _ color: Color) {
        context.fill(
            Path(BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)),
            with: .color(color),
        )
    }

    // MARK: - Digits & notes

    private func drawDigits(_ context: GraphicsContext) {
        for index in 0 ..< session.board.count {
            // Fogged cells hide their contents — givens included.
            if session.isFogged(index) {
                let rect = BoardDecorations.cellRect(
                    index,
                    topology: topology,
                    cellSize: cellSize,
                )
                context.fill(
                    Path(rect),
                    with: .color(theme.gridLineBold.opacity(0.22)),
                )
                continue
            }
            let cell = session.board[index]
            if let value = cell.value {
                drawValue(context, value: value, cell: cell, index: index)
            } else if !cell.notes.isEmpty {
                drawNotes(context, cell: cell, index: index)
            }
        }
    }

    private func drawValue(_ context: GraphicsContext, value: Int, cell: BoardCell, index: Int) {
        let center = BoardDecorations.cellCenter(index, topology: topology, cellSize: cellSize)
        let isWrong = !cell.isGiven && value != session.puzzle.solution[index]
        let color: Color = if isWrong, settings.mistakeHighlighting {
            theme.conflict
        } else if cell.isGiven {
            theme.givenText
        } else {
            theme.playerText
        }
        let glyph = VariantGlyphs.glyph(value, for: session.puzzle.variant)
        // Two-character values (10–16 on big grids) need a smaller face.
        let text = Text(glyph)
            .font(.system(
                size: cellSize * (glyph.count > 1 ? 0.44 : 0.55),
                weight: cell.isGiven ? .semibold : .regular,
                design: .rounded,
            ))
            .foregroundStyle(color)
        context.draw(context.resolve(text), at: center, anchor: .center)
    }

    private func drawNotes(_ context: GraphicsContext, cell: BoardCell, index: Int) {
        let rect = BoardDecorations.cellRect(index, topology: topology, cellSize: cellSize)
        for digit in cell.notes.digits where digit <= topology.size {
            let point = BoardDecorations.notePoint(for: digit, in: rect, size: topology.size)
            let glyph = VariantGlyphs.glyph(digit, for: session.puzzle.variant)
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
