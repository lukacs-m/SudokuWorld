import SwiftUI

/// Chart colours in the theme's own roles, so multi-series charts never fall
/// back to the system blue/green/orange that clashes with the sage palettes.
/// Sector one is the accent, two the gold and three the success colour as the
/// palette defines them; four and seven are the accent rotated 78 degrees
/// either way around the colour wheel; six and eight are the gold rotated 35
/// degrees either way; five is the success colour stepped 0.25 darker. A
/// rotation and a step both carry the base's own saturation over untouched,
/// so a muted palette keeps muted sectors. The success colour takes the
/// brightness step rather than a rotation because two palettes make it the
/// same hue as the accent (identical in forest, two degrees apart in warm
/// paper), and where that is so, sector three is stepped the other way so
/// the pair straddles the accent instead of repeating it.
enum StatsPalette {
    private static let accentRotation: Double = 78
    private static let goldRotation: Double = 35
    private static let brightnessStep = 0.25

    static func series(count: Int, theme: Theme) -> [Color] {
        let ramp = ramp(theme: theme)
        return (0 ..< count).map { ramp[$0 % ramp.count] }
    }

    private static func ramp(theme: Theme) -> [Color] {
        let accent = HSB(theme.accent)
        let gold = HSB(theme.gold)
        let success = HSB(theme.success)
        return [
            theme.accent,
            theme.gold,
            success.sharesHueFamily(with: accent)
                ? success.color(brightnessStep: brightnessStep)
                : theme.success,
            accent.color(hueOffset: accentRotation),
            success.color(brightnessStep: -brightnessStep),
            gold.color(hueOffset: goldRotation),
            accent.color(hueOffset: -accentRotation),
            gold.color(hueOffset: -goldRotation),
        ]
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

    /// Close enough in hue that a donut legend reads the two as one colour.
    func sharesHueFamily(with other: Self) -> Bool {
        let gap = abs(hue - other.hue)
        return min(gap, 1 - gap) < 25.0 / 360
    }

    func color(hueOffset: Double = 0, brightnessStep: Double = 0) -> Color {
        Color(
            hue: (hue + hueOffset / 360 + 1).truncatingRemainder(dividingBy: 1),
            saturation: saturation,
            brightness: min(max(brightness + brightnessStep, 0.12), 0.95),
        )
    }
}
