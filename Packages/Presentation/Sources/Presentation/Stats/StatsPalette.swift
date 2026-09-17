import SwiftUI

/// Chart colours derived from the theme so multi-series charts never fall
/// back to the system blue/green/orange that clashes with the sage palettes.
enum StatsPalette {
    static func series(count: Int, theme: Theme) -> [Color] {
        let ramp = ramp(theme: theme)
        return (0 ..< count).map { ramp[$0 % ramp.count] }
    }

    /// Accent, gold and success, then a darker and a lighter step of the same
    /// three. Every step differs by base as well as by lap, so the forest
    /// palette - whose accent and success are the same green - still yields
    /// eight sectors a legend can be matched against.
    private static func ramp(theme: Theme) -> [Color] {
        [
            theme.accent,
            theme.gold,
            theme.success.mix(with: .white, by: 0.20),
            theme.accent.mix(with: .black, by: 0.32),
            theme.gold.mix(with: .black, by: 0.26),
            theme.success.mix(with: .black, by: 0.38),
            theme.accent.mix(with: .white, by: 0.34),
            theme.gold.mix(with: .white, by: 0.40),
        ]
    }
}
