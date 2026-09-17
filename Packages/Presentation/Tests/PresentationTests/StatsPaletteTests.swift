import Model
import SwiftUI
import Testing

@testable import Presentation

struct StatsPaletteTests {
    /// The donut caps itself at eight sectors, so eight is exactly how many
    /// colours a legend has to be able to tell apart - in every palette,
    /// including the forest one whose accent and success are the same green.
    @Test(arguments: ThemeID.allCases, [ColorScheme.light, ColorScheme.dark])
    func theFirstEightSeriesColoursAreDistinct(id: ThemeID, scheme: ColorScheme) {
        let theme = ThemePalettes.palette(for: id, scheme: scheme)
        let colors = StatsPalette.series(count: 8, theme: theme)
            .map { $0.resolve(in: EnvironmentValues()) }

        #expect(colors.count == 8)
        for (offset, color) in colors.enumerated() {
            for other in colors[(offset + 1)...] {
                #expect(color != other, "\(id) \(scheme): repeated sector colour \(color)")
            }
        }
    }

    @Test func moreSeriesThanTheRampWrapAroundIt() {
        let colors = StatsPalette.series(count: 9, theme: ThemePalettes.palette(
            for: .slate,
            scheme: .light,
        ))
        #expect(colors.count == 9)
        #expect(colors[8] == colors[0])
    }
}
