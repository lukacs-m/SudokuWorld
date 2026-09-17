import SwiftUI

/// Chart colours in the theme's own roles, so multi-series charts never fall
/// back to the system blue/green/orange that clashes with the sage palettes.
/// Sectors one to three are the accent, the gold and the success colour as
/// the palette defines them; four to six are those three rotated 35 degrees
/// around the colour wheel; seven and eight are the accent and the gold
/// rotated 35 degrees the other way. A rotation carries the base's own
/// saturation and brightness over untouched, so a muted palette keeps muted
/// sectors. Where the success colour *is* the accent (forest) the ramp would
/// repeat a sector, so there the success pair takes a darker step of it.
enum StatsPalette {
    static func series(count: Int, theme: Theme) -> [Color] {
        let ramp = ramp(theme: theme)
        return (0 ..< count).map { ramp[$0 % ramp.count] }
    }

    private static func ramp(theme: Theme) -> [Color] {
        let rotation: Double = 35
        let success = theme.success.components == theme.accent.components
            ? theme.success.mix(with: .black, by: 0.4)
            : theme.success
        return [
            theme.accent,
            theme.gold,
            success,
            theme.accent.rotatingHue(by: rotation),
            theme.gold.rotatingHue(by: rotation),
            success.rotatingHue(by: rotation),
            theme.accent.rotatingHue(by: -rotation),
            theme.gold.rotatingHue(by: -rotation),
        ]
    }
}

private extension Color {
    var components: Color.Resolved {
        resolve(in: EnvironmentValues())
    }

    /// SwiftUI builds a `Color` from HSB but will not take one apart again,
    /// and the UIKit and AppKit bridges that would are per platform.
    func rotatingHue(by degrees: Double) -> Color {
        let resolved = components
        let red = Double(resolved.red)
        let green = Double(resolved.green)
        let blue = Double(resolved.blue)
        let high = max(red, green, blue)
        let spread = high - min(red, green, blue)
        guard spread > 0 else { return self }
        let sixth: Double = switch high {
        case red: (green - blue) / spread
        case green: 2 + (blue - red) / spread
        default: 4 + (red - green) / spread
        }
        return Color(
            hue: (sixth / 6 + degrees / 360 + 1).truncatingRemainder(dividingBy: 1),
            saturation: spread / high,
            brightness: high,
        )
    }
}
