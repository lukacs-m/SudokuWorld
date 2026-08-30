import CoreGraphics

/// Committed zoom state for the board: a scale plus a pan offset measured from
/// the centered position. Always stored clamped, so content edges never pull
/// inside the viewport and scale 1 always means offset zero.
struct BoardZoom: Equatable {
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    /// Zoom until one cell is roughly a classic-board cell (dimension/9).
    /// Classic-size and smaller boards get 1: zoom and pan are no-ops there.
    static func maxScale(rows: Int, cols: Int) -> CGFloat {
        max(1, CGFloat(max(rows, cols)) / 9)
    }

    func clamped(base: CGSize, maxScale: CGFloat) -> Self {
        let clampedScale = min(max(scale, 1), maxScale)
        let maxX = base.width * (clampedScale - 1) / 2
        let maxY = base.height * (clampedScale - 1) / 2
        return Self(
            scale: clampedScale,
            offset: CGSize(
                width: min(max(offset.width, -maxX), maxX),
                height: min(max(offset.height, -maxY), maxY),
            ),
        )
    }

    /// Pinch anchored at `anchor`, measured from the viewport center: the
    /// board point under the anchor stays put (until clamping engages).
    func zoomed(
        by ratio: CGFloat,
        about anchor: CGPoint,
        base: CGSize,
        maxScale: CGFloat,
    ) -> Self {
        let newScale = min(max(scale * ratio, 1), maxScale)
        let effective = newScale / scale
        return Self(
            scale: newScale,
            offset: CGSize(
                width: (offset.width - anchor.x) * effective + anchor.x,
                height: (offset.height - anchor.y) * effective + anchor.y,
            ),
        ).clamped(base: base, maxScale: maxScale)
    }

    func panned(by translation: CGSize, base: CGSize, maxScale: CGFloat) -> Self {
        Self(
            scale: scale,
            offset: CGSize(
                width: offset.width + translation.width,
                height: offset.height + translation.height,
            ),
        ).clamped(base: base, maxScale: maxScale)
    }

    /// A point in the viewport's local space mapped back to unzoomed board
    /// space, for tap hit testing.
    func boardPoint(_ point: CGPoint, base: CGSize) -> CGPoint {
        let originX = (base.width - base.width * scale) / 2 + offset.width
        let originY = (base.height - base.height * scale) / 2 + offset.height
        return CGPoint(x: (point.x - originX) / scale, y: (point.y - originY) / scale)
    }
}
