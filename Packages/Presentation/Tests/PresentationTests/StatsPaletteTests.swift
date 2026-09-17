import Foundation
import Model
import SwiftUI
import Testing

@testable import Presentation

struct StatsPaletteTests {
    /// The donut caps itself at eight sectors, so eight is exactly how many
    /// colours a legend has to be able to tell apart - in every palette,
    /// including the muted ones and the amber pair, whose accent and gold
    /// share a hue and so lean hardest on the brightness steps. The measured
    /// ΔE76 floor across all eleven palettes is 9.8 (warm paper dark, whose
    /// accent walk is the one most shortened to clear its card), so the bar
    /// sits at 8: a palette or ramp edit that pushes a pair below that fails
    /// here rather than shipping a legend that cannot be matched.
    @Test(arguments: ThemeID.allCases, [ColorScheme.light, ColorScheme.dark])
    func theFirstEightSeriesColoursStayPerceptuallyApart(id: ThemeID, scheme: ColorScheme) {
        let theme = ThemePalettes.palette(for: id, scheme: scheme)
        let sectors = StatsPalette.series(count: 8, theme: theme)
            .map { LabColor($0.resolve(in: EnvironmentValues())) }

        #expect(sectors.count == 8)
        for (offset, sector) in sectors.enumerated() {
            for (other, color) in sectors.enumerated().dropFirst(offset + 1) {
                let distance = sector.distance(to: color)
                #expect(
                    distance >= 8,
                    "\(id) \(scheme): sectors \(offset) and \(other) are ΔE \(distance) apart",
                )
            }
        }
    }

    /// Sectors are drawn on the card with an angular inset that lets it show
    /// through the gaps, so every sector has to stand off the card - the
    /// dominant slice included, since it takes the first colour of the ramp.
    /// The measured floor is 21.2 (slate dark); the walk shortens its step
    /// per palette to hold that rather than fading into the card.
    @Test(arguments: ThemeID.allCases, [ColorScheme.light, ColorScheme.dark])
    func everySeriesColourStandsOffTheCard(id: ThemeID, scheme: ColorScheme) {
        let theme = ThemePalettes.palette(for: id, scheme: scheme)
        let card = LabColor(theme.cardBackground.resolve(in: EnvironmentValues()))

        for (index, sector) in StatsPalette.series(count: 8, theme: theme).enumerated() {
            let distance = LabColor(sector.resolve(in: EnvironmentValues())).distance(to: card)
            #expect(
                distance >= 20,
                "\(id) \(scheme): sector \(index) is only ΔE \(distance) from the card",
            )
        }
    }

    @Test func moreSeriesThanTheRampWrapAroundIt() {
        let theme = ThemePalettes.palette(for: .slate, scheme: .light)
        let colors = StatsPalette.series(count: 9, theme: theme)

        #expect(colors.count == 9)
        #expect(colors[8] == colors[0])
        #expect(colors[0] == theme.accent)
        #expect(colors[1] == theme.gold)
    }
}

/// CIE L*a*b*, so "these two sectors look alike" is a number instead of a
/// judgement: a ΔE76 in the single digits is a pair no legend can be matched
/// against, however far apart the two colours are as raw RGB.
private struct LabColor {
    private let lightness: Double
    private let a: Double
    private let b: Double

    init(_ color: Color.Resolved) {
        let red = Double(color.linearRed)
        let green = Double(color.linearGreen)
        let blue = Double(color.linearBlue)
        let x = Self.curve((0.4124 * red + 0.3576 * green + 0.1805 * blue) / 0.95047)
        let y = Self.curve(0.2126 * red + 0.7152 * green + 0.0722 * blue)
        let z = Self.curve((0.0193 * red + 0.1192 * green + 0.9505 * blue) / 1.08883)
        lightness = 116 * y - 16
        a = 500 * (x - y)
        b = 200 * (y - z)
    }

    func distance(to other: Self) -> Double {
        let lightnessDelta = lightness - other.lightness
        let aDelta = a - other.a
        let bDelta = b - other.b
        return (lightnessDelta * lightnessDelta + aDelta * aDelta + bDelta * bDelta).squareRoot()
    }

    private static func curve(_ value: Double) -> Double {
        value > 0.008856 ? cbrt(value) : 7.787 * value + 16 / 116
    }
}
