import CoreGraphics
import Domain
import Model
import Testing
@testable import Presentation

/// Little-killer clues must sit on the extension of the diagonal they sum:
/// the player reads the arrow as pointing along the diagonal's cell centers,
/// so an anchor off that line makes the clue name the wrong diagonal.
@Suite
@MainActor
struct OutsideClueOverlayTests {
    private let topology = TopologyFactory.topology(for: .littleKiller)
    private let cellSize: CGFloat = 10
    private let gutter: CGFloat = 10

    /// First cell and reading direction per side, matching the engine's
    /// fixed convention: top ↘, trailing ↙, bottom ↖, leading ↗.
    private func diagonal(side: OutsideClue.Side, offset: Int) -> (first: (row: Int, col: Int), step: (row: Int, col: Int)) {
        let last = topology.size - 1
        return switch side {
        case .top: ((0, offset), (1, 1))
        case .trailing: ((offset, last), (1, -1))
        case .bottom: ((last, offset), (-1, -1))
        case .leading: ((offset, 0), (-1, 1))
        }
    }

    private func center(row: Int, col: Int) -> CGPoint {
        CGPoint(
            x: gutter + (CGFloat(col) + 0.5) * cellSize,
            y: gutter + (CGFloat(row) + 0.5) * cellSize,
        )
    }

    @Test func littleKillerLabelsLieOnTheirDiagonal() {
        for side in [OutsideClue.Side.top, .trailing, .bottom, .leading] {
            for offset in 1 ..< topology.size {
                let clue = OutsideClue(kind: .diagonalSum, side: side, offset: offset, value: 0)
                let (first, step) = diagonal(side: side, offset: offset)
                guard first.row + step.row >= 0, first.row + step.row < topology.size,
                      first.col + step.col >= 0, first.col + step.col < topology.size
                else { continue } // one-cell diagonals never get clues

                let anchor = OutsideClueOverlay.position(
                    for: clue,
                    topology: topology,
                    cellSize: cellSize,
                    gutter: gutter,
                )
                let firstCenter = center(row: first.row, col: first.col)
                let toFirst = CGPoint(x: firstCenter.x - anchor.x, y: firstCenter.y - anchor.y)

                // Collinear with the diagonal: the vector from the label to the
                // first cell must match the reading direction in both axes.
                #expect(
                    abs(toFirst.x) == abs(toFirst.y),
                    "\(side) \(offset): anchor \(anchor) off the diagonal through \(firstCenter)",
                )
                // And point INTO the grid, so the label precedes the first cell.
                #expect(
                    toFirst.x * CGFloat(step.col) > 0 && toFirst.y * CGFloat(step.row) > 0,
                    "\(side) \(offset): anchor \(anchor) not before the diagonal's entry",
                )
            }
        }
    }
}
