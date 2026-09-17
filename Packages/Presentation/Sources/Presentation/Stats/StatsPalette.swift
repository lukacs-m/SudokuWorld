import SwiftUI

/// Chart colours that start on the theme's own roles: the first sector is
/// `theme.accent` and the second `theme.gold` exactly as the palette defines
/// them, so the biggest slice of a donut carries the theme's own colour. Each
/// family then walks three more shades away from its base, 0.20 of brightness
/// at a time with hue and saturation untouched, so no sector lands on a hue
/// the theme does not already use. On a dark card the walk fades toward the
/// card and stops a margin short of it; on a light card it deepens instead,
/// because the palettes put their gold at 0.95 brightness or above and a
/// tint that pale cannot be told from white with saturation held fixed. The
/// gold walk stops one step earlier than the accent walk so the two ladders
/// never converge on the same brightness - that is what keeps the amber
/// palettes apart, whose accent and gold are seven degrees of hue from each
/// other.
enum StatsPalette {
    private static let maxStep = 0.20
    private static let cardMargin = 0.22
    private static let darkestSector = 0.15
    private static let goldStagger = 0.14

    static func series(count: Int, theme: Theme) -> [Color] {
        let ramp = ramp(theme: theme)
        return (0 ..< count).map { ramp[$0 % ramp.count] }
    }

    private static func ramp(theme: Theme) -> [Color] {
        let limit = limit(card: HSB(theme.cardBackground))
        let accent = walk(from: theme.accent, stoppingAt: limit)
        let gold = walk(from: theme.gold, stoppingAt: limit + goldStagger)
        return (0 ..< 4).flatMap { [accent[$0], gold[$0]] }
    }

    /// The brightness a walk must not pass: a margin above a dark card, so
    /// the last shade still stands off it, and short of black on a light one.
    private static func limit(card: HSB) -> Double {
        card.brightness < 0.5 ? card.brightness + cardMargin : darkestSector
    }

    /// Four shades from the base, a full step apart unless that would carry
    /// the last one past the limit, in which case the step shortens to land
    /// exactly on it.
    private static func walk(from base: Color, stoppingAt limit: Double) -> [Color] {
        let hsb = HSB(base)
        let step = min(maxStep, max(0, hsb.brightness - limit) / 3)
        return (0 ..< 4).map { index in
            guard index > 0 else { return base }
            return hsb.color(brightness: hsb.brightness - Double(index) * step)
        }
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
