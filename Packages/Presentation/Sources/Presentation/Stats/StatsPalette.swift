import SwiftUI

/// Chart colours derived from the theme so multi-series charts never fall
/// back to the system blue/green/orange that clashes with the sage palettes.
enum StatsPalette {
    static func series(count: Int, theme: Theme) -> [Color] {
        let ramp = ramp(theme: theme)
        return (0 ..< count).map { ramp[$0 % ramp.count] }
    }

    /// Eight sectors spread an eighth of the colour wheel apart from the
    /// theme's own accent hue, every other one dimmed. Pairing accent, gold
    /// and success with lightness steps cannot keep eight sectors apart in
    /// every palette: forest's accent and success are the same green, and
    /// rose's accent and gold sit about an eighth of the wheel apart. Washed
    /// out accents get their saturation lifted so neighbouring sectors stay
    /// tellable apart at sector size.
    private static func ramp(theme: Theme) -> [Color] {
        let base = HSBComponents(theme.accent)
        return (0 ..< 8).map { index in
            let dimmed = base.brightness - (index.isMultiple(of: 2) ? 0 : 0.12)
            return Color(
                hue: (base.hue + Double(index) / 8).truncatingRemainder(dividingBy: 1),
                saturation: max(base.saturation, 0.65),
                brightness: min(max(dimmed, 0.42), 0.9),
            )
        }
    }
}

/// SwiftUI builds a `Color` from HSB but will not take one apart again, and
/// the UIKit and AppKit bridges that would are per platform.
private struct HSBComponents {
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
}
