import SwiftUI

/// Chart colours from two of the theme's own roles, so multi-series charts
/// never fall back to the system blue/green/orange that clashes with the sage
/// palettes. The eight sectors are four brightness steps of the accent
/// interleaved with four of the gold - accent, gold, accent one step on, gold
/// one step on, and so on - with hue and saturation carried over untouched,
/// so a muted palette keeps muted sectors and no sector lands on a hue the
/// theme does not already use. The steps walk away from the card background,
/// darker on a light palette and lighter on a dark one, starting far enough
/// from it that the dimmest sector still reads; the gold ladder is offset
/// half a step from the accent one, which is what keeps the two families
/// apart in the amber palettes, whose accent and gold sit seven degrees of
/// hue from each other.
enum StatsPalette {
    private static let step = 0.19
    private static let goldOffset = 0.08
    private static let lightCardAnchor = 0.94
    private static let darkCardAnchor = 0.34

    static func series(count: Int, theme: Theme) -> [Color] {
        let ramp = ramp(theme: theme)
        return (0 ..< count).map { ramp[$0 % ramp.count] }
    }

    private static func ramp(theme: Theme) -> [Color] {
        let accent = HSB(theme.accent)
        let gold = HSB(theme.gold)
        let onDarkCard = HSB(theme.cardBackground).brightness < 0.5
        return (0 ..< 4).flatMap { index in
            let accentStep = brightness(index, offset: 0, onDarkCard: onDarkCard)
            let goldStep = brightness(index, offset: goldOffset, onDarkCard: onDarkCard)
            return [accent.color(brightness: accentStep), gold.color(brightness: goldStep)]
        }
    }

    private static func brightness(_ index: Int, offset: Double, onDarkCard: Bool) -> Double {
        let walked = Double(index) * step + offset
        return onDarkCard ? darkCardAnchor + walked : lightCardAnchor - walked
    }
}

/// SwiftUI builds a `Color` from HSB but will not take one apart again, and
/// the UIKit and AppKit bridges that would are per platform.
private struct HSB {
    let hue: Double
    let saturation: Double
    let brightness: Double

    init(_ color: Color) {
        let resolved = color.resolve(in: EnvironmentValues())
        let red = Double(resolved.red)
        let green = Double(resolved.green)
        let blue = Double(resolved.blue)
        let high = max(red, green, blue)
        let spread = high - min(red, green, blue)
        brightness = high
        saturation = high > 0 ? spread / high : 0
        guard spread > 0 else {
            hue = 0
            return
        }
        let sixth: Double = switch high {
        case red: (green - blue) / spread
        case green: 2 + (blue - red) / spread
        default: 4 + (red - green) / spread
        }
        hue = (sixth / 6 + 1).truncatingRemainder(dividingBy: 1)
    }

    func color(brightness: Double) -> Color {
        Color(
            hue: hue,
            saturation: saturation,
            brightness: min(max(brightness, 0.05), 1),
        )
    }
}
