import CoreGraphics
import Domain
import Model
import Testing
@testable import Presentation

@Suite
struct BoardZoomTests {
    private let base = CGSize(width: 300, height: 400)

    @Test func scaleClampsToBounds() {
        let zoomedOut = BoardZoom().zoomed(by: 0.1, about: .zero, base: base, maxScale: 3)
        #expect(zoomedOut == BoardZoom())

        let zoomedIn = BoardZoom().zoomed(by: 100, about: .zero, base: base, maxScale: 3)
        #expect(zoomedIn.scale == 3)
    }

    @Test func offsetIsZeroAtScaleOne() {
        let panned = BoardZoom().panned(
            by: CGSize(width: 200, height: 200),
            base: base,
            maxScale: 3,
        )
        #expect(panned == BoardZoom())
    }

    @Test func offsetClampSymmetricAtScaleTwo() {
        let zoom = BoardZoom(scale: 2)
        let far = CGSize(width: 10_000, height: 10_000)

        let positive = zoom.panned(by: far, base: base, maxScale: 3).offset
        #expect(positive == CGSize(width: 150, height: 200))

        let negative = zoom.panned(
            by: CGSize(width: -far.width, height: -far.height),
            base: base,
            maxScale: 3,
        ).offset
        #expect(negative == CGSize(width: -150, height: -200))
    }

    @Test func zoomOutReclampsOffset() {
        let edge = BoardZoom(scale: 3, offset: CGSize(width: 300, height: 400))
        let shrunk = edge.zoomed(by: 0.5, about: .zero, base: base, maxScale: 3)
        #expect(shrunk.scale == 1.5)
        #expect(abs(shrunk.offset.width) <= base.width * 0.25)
        #expect(abs(shrunk.offset.height) <= base.height * 0.25)
    }

    @Test(arguments: [
        (SudokuVariant.shogun, CGFloat(5)),
        (.sumo, 33 / 9),
        (.alphadoku25, 25 / 9),
        (.hexadoku16, 16 / 9),
        // Normal-size boards must not zoom at all.
        (.classic, 1),
        (.killer, 1),
        (.mini6, 1),
    ])
    func maxScalePerVariant(variant: SudokuVariant, expected: CGFloat) {
        let topology = TopologyFactory.topology(for: variant)
        let maxScale = BoardZoom.maxScale(rows: topology.rowCount, cols: topology.colCount)
        #expect(abs(maxScale - expected) < 0.0001)
    }

    @Test func pinchAnchorStaysFixed() {
        let zoom = BoardZoom(scale: 1.5, offset: CGSize(width: 20, height: -30))
        let anchor = CGPoint(x: 40, y: 60)
        let slotPoint = CGPoint(x: anchor.x + base.width / 2, y: anchor.y + base.height / 2)

        let before = zoom.boardPoint(slotPoint, base: base)
        let after = zoom.zoomed(by: 1.4, about: anchor, base: base, maxScale: 5)
            .boardPoint(slotPoint, base: base)

        #expect(abs(before.x - after.x) < 0.0001)
        #expect(abs(before.y - after.y) < 0.0001)
    }

    @Test func boardPointRoundTrip() {
        let identity = BoardZoom().boardPoint(CGPoint(x: 123, y: 45), base: base)
        #expect(identity == CGPoint(x: 123, y: 45))

        // At scale 2 with a known offset, the viewport point where a board
        // point renders must map back to that board point:
        // viewport = boardPoint * scale + origin.
        let zoom = BoardZoom(scale: 2, offset: CGSize(width: 50, height: -80))
        let board = CGPoint(x: 105, y: 215)
        let origin = CGPoint(
            x: (base.width - base.width * 2) / 2 + 50,
            y: (base.height - base.height * 2) / 2 - 80,
        )
        let viewport = CGPoint(x: board.x * 2 + origin.x, y: board.y * 2 + origin.y)
        #expect(zoom.boardPoint(viewport, base: base) == board)
    }
}
