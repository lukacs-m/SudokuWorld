import SwiftUI

/// Chart colours derived from the theme so multi-series charts never fall
/// back to the system blue/green/orange that clashes with the sage palettes.
enum StatsPalette {
    /// The hint gold the streak card and the hint highlight already draw with.
    static let hintGold = Color(red: 0.753, green: 0.600, blue: 0.294)

    /// Accent, gold, success, then markedly lighter tints of the same three:
    /// the gold keeps the two theme greens apart, the tint steps keep a
    /// second lap of the palette apart from the first.
    static func series(count: Int, theme: Theme) -> [Color] {
        let base = [theme.accent, hintGold, theme.success]
        return (0 ..< count).map { index in
            let tint = 1 - 0.35 * Double(index / base.count)
            return base[index % base.count].opacity(max(0.3, tint))
        }
    }
}
