import CoreGraphics
import Foundation
import Model
import SwiftUI
import Testing
@testable import Presentation

/// The CoreGraphics face renderer must draw what the flat board draws:
/// highlight fills under the digits, digits in the theme's ink, and it must
/// run off the main actor so a tap never waits on a texture.
@Suite
struct CubeFaceRendererTests {
    private let palette = CubeFaceSnapshot.Palette(
        theme: ThemePalettes.palette(for: .warmPaper, scheme: .light),
    )

    private struct Pixels {
        let data: Data
        let bytesPerRow: Int

        init?(_ image: CGImage) {
            guard let provider = image.dataProvider?.data else { return nil }
            data = provider as Data
            bytesPerRow = image.bytesPerRow
        }

        func matches(_ color: Color.Resolved, x: Int, y: Int) -> Bool {
            let offset = y * bytesPerRow + x * 4
            let channels = [color.red, color.green, color.blue]
            return channels.enumerated().allSatisfy { index, expected in
                abs(Int(data[offset + index]) - Int(expected * 255)) <= 2
            }
        }
    }

    @Test func rendersHighlightsAndDigitsOffTheMainActor() async throws {
        var cells = Array(repeating: CubeFaceSnapshot.Cell(), count: 9)
        cells[0].isSelected = true
        cells[1].isRelated = true
        cells[4].value = 5
        cells[4].isGiven = true
        cells[8].notes = [1, 9]
        let snapshot = CubeFaceSnapshot(cells: cells, palette: palette)

        let rendered = await Task.detached { await CubeFaceRenderer.render(snapshot) }.value
        let image = try #require(rendered)
        #expect(image.width == CubeFaceRenderer.pixels)
        #expect(image.height == CubeFaceRenderer.pixels)
        let pixels = try #require(Pixels(image))

        // Fills composite over the cell background exactly as on the flat board.
        let cell = CubeFaceRenderer.pixels / 3
        let selection = palette.selection
        let base = palette.cellBackground
        let alpha = selection.opacity
        let blended = Color.Resolved(
            red: base.red * (1 - alpha) + selection.red * alpha,
            green: base.green * (1 - alpha) + selection.green * alpha,
            blue: base.blue * (1 - alpha) + selection.blue * alpha,
        )
        #expect(pixels.matches(blended, x: 24, y: 24))
        #expect(!pixels.matches(base, x: cell + 24, y: 24))
        #expect(pixels.matches(base, x: 2 * cell + 24, y: 24))

        // Something in the given's ink is drawn in the centre cell, and
        // notes leave marks in the bottom-right cell.
        #expect(hasInk(pixels, cellX: 1, cellY: 1, color: palette.givenText, cell: cell))
        #expect(hasInk(pixels, cellX: 2, cellY: 2, color: palette.noteText, cell: cell))
        #expect(!hasInk(pixels, cellX: 2, cellY: 0, color: palette.givenText, cell: cell))
    }

    /// What a tap costs: `CubeScene` hands each invalidated face off instead
    /// of drawing it on the main actor, so dispatching all six faces must cost
    /// a fraction of drawing them, and every face must still arrive.
    @MainActor
    @Test func dispatchingSixFacesCostsFarLessMainActorTimeThanDrawingThem() async throws {
        let snapshot = fullFace()
        let clock = ContinuousClock()

        let start = clock.now
        let renders = (0 ..< 6).map { _ in
            Task(priority: .userInitiated) { await CubeFaceRenderer.render(snapshot) }
        }
        let dispatch = clock.now - start
        var images: [CGImage?] = []
        for render in renders {
            images.append(await render.value)
        }
        let ready = clock.now - start
        let synchronous = clock.measure {
            for _ in 0 ..< 6 {
                _ = CubeFaceRenderer.draw(snapshot)
            }
        }

        print(
            """
            six faces — main-actor dispatch: \(dispatch), all textures ready \
            after: \(ready), drawing them on the main actor instead: \(synchronous)
            """,
        )
        #expect(images.allSatisfy { $0 != nil })
        #expect(dispatch * 10 < synchronous)
    }

    private func fullFace() -> CubeFaceSnapshot {
        var cells = Array(repeating: CubeFaceSnapshot.Cell(), count: 9)
        for offset in cells.indices {
            cells[offset].value = offset + 1
            cells[offset].isGiven = offset.isMultiple(of: 2)
            cells[offset].isRelated = true
        }
        cells[0].isSelected = true
        return CubeFaceSnapshot(cells: cells, palette: palette)
    }

    private func hasInk(
        _ pixels: Pixels,
        cellX: Int,
        cellY: Int,
        color: Color.Resolved,
        cell: Int,
    ) -> Bool {
        for y in stride(from: cellY * cell + 16, to: (cellY + 1) * cell - 16, by: 4) {
            for x in stride(from: cellX * cell + 16, to: (cellX + 1) * cell - 16, by: 4)
                where pixels.matches(color, x: x, y: y) {
                return true
            }
        }
        return false
    }
}
