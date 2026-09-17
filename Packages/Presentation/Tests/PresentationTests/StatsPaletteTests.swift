import Foundation
import Model
import SwiftUI
import Testing

@testable import Presentation

struct StatsPaletteTests {
    /// The donut caps itself at eight sectors, so eight is exactly how many
    /// colours a legend has to be able to tell apart - in every palette,
    /// including the muted ones (warm paper, slate) and the forest one whose
    /// accent and success are the same green. A ΔE76 of 12 is about where two
    /// chart sectors stop reading as the same colour; the ramp's own floor is
    /// 13.2 (amber dark), so a palette or ramp edit that drops a pair below
    /// that bar fails here rather than shipping an unreadable legend.
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
                    distance >= 12,
                    "\(id) \(scheme): sectors \(offset) and \(other) are ΔE \(distance) apart",
                )
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
