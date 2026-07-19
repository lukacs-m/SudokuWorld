public import Model
public import SwiftUI

/// The six palettes (three free, three premium), each with a light and dark
/// rendition. Pure data — the store picks, views draw.
public enum ThemePalettes {
    public static func palette(for id: ThemeID, scheme: ColorScheme) -> Theme {
        scheme == .dark ? darkPalette(for: id) : lightPalette(for: id)
    }

    private static func lightPalette(for id: ThemeID) -> Theme {
        switch id {
        case .warmPaper: warmPaperLight
        case .slate: slateLight
        case .forest: forestLight
        case .midnight: midnight // deliberately always-dark
        case .rose: roseLight
        case .amber: amberLight
        }
    }

    private static func darkPalette(for id: ThemeID) -> Theme {
        switch id {
        case .warmPaper: warmPaperDark
        case .slate: slateDark
        case .forest: forestDark
        case .midnight: midnight
        case .rose: roseDark
        case .amber: amberDark
        }
    }

    // MARK: - Free themes

    // Warm Paper: off-white paper, warm ink, muted sage accent, gold hints.
    private static let warmPaperLight = Theme(
        id: .warmPaper,
        accent: Color(red: 0.431, green: 0.557, blue: 0.486),
        screenBackground: Color(red: 0.965, green: 0.953, blue: 0.925),
        cardBackground: .white,
        boardBackground: .white,
        cellBackground: .white,
        cellBackgroundAlternate: Color(red: 0.937, green: 0.922, blue: 0.882),
        gridLine: Color(red: 0.851, green: 0.831, blue: 0.780),
        gridLineBold: Color(red: 0.333, green: 0.314, blue: 0.247),
        givenText: Color(red: 0.137, green: 0.129, blue: 0.110),
        playerText: Color(red: 0.431, green: 0.557, blue: 0.486),
        noteText: Color(red: 0.541, green: 0.522, blue: 0.467),
        selection: Color(red: 0.431, green: 0.557, blue: 0.486).opacity(0.30),
        relatedHighlight: Color(red: 0.431, green: 0.557, blue: 0.486).opacity(0.10),
        sameDigitHighlight: Color(red: 0.431, green: 0.557, blue: 0.486).opacity(0.18),
        conflict: Color(red: 0.757, green: 0.373, blue: 0.286),
        hintHighlight: Color(red: 0.753, green: 0.600, blue: 0.294).opacity(0.35),
        success: Color(red: 0.310, green: 0.478, blue: 0.384),
        textPrimary: Color(red: 0.137, green: 0.129, blue: 0.110),
        textSecondary: Color(red: 0.541, green: 0.522, blue: 0.467),
    )

    private static let warmPaperDark = Theme(
        id: .warmPaper,
        accent: Color(red: 0.525, green: 0.659, blue: 0.588),
        screenBackground: Color(red: 0.102, green: 0.094, blue: 0.075),
        cardBackground: Color(red: 0.129, green: 0.122, blue: 0.090),
        boardBackground: Color(red: 0.129, green: 0.122, blue: 0.090),
        cellBackground: Color(red: 0.129, green: 0.122, blue: 0.090),
        cellBackgroundAlternate: Color(red: 0.165, green: 0.157, blue: 0.125),
        gridLine: Color(red: 0.302, green: 0.290, blue: 0.247),
        gridLineBold: Color(red: 0.639, green: 0.620, blue: 0.561),
        givenText: Color(red: 0.925, green: 0.910, blue: 0.871),
        playerText: Color(red: 0.525, green: 0.659, blue: 0.588),
        noteText: Color(red: 0.639, green: 0.620, blue: 0.561),
        selection: Color(red: 0.525, green: 0.659, blue: 0.588).opacity(0.35),
        relatedHighlight: Color(red: 0.525, green: 0.659, blue: 0.588).opacity(0.12),
        sameDigitHighlight: Color(red: 0.525, green: 0.659, blue: 0.588).opacity(0.22),
        conflict: Color(red: 0.851, green: 0.482, blue: 0.388),
        hintHighlight: Color(red: 0.831, green: 0.686, blue: 0.416).opacity(0.35),
        success: Color(red: 0.463, green: 0.635, blue: 0.537),
        textPrimary: Color(red: 0.925, green: 0.910, blue: 0.871),
        textSecondary: Color(red: 0.639, green: 0.620, blue: 0.561),
    )

    private static let slateLight = Theme(
        id: .slate,
        accent: Color(red: 0.35, green: 0.42, blue: 0.55),
        screenBackground: Color(red: 0.96, green: 0.96, blue: 0.97),
        cardBackground: .white,
        boardBackground: .white,
        cellBackground: .white,
        cellBackgroundAlternate: Color(red: 0.92, green: 0.93, blue: 0.95),
        gridLine: Color(red: 0.78, green: 0.80, blue: 0.83),
        gridLineBold: Color(red: 0.30, green: 0.33, blue: 0.38),
        givenText: Color(red: 0.13, green: 0.15, blue: 0.18),
        playerText: Color(red: 0.35, green: 0.42, blue: 0.55),
        noteText: Color(red: 0.50, green: 0.53, blue: 0.58),
        selection: Color(red: 0.35, green: 0.42, blue: 0.55).opacity(0.28),
        relatedHighlight: Color(red: 0.35, green: 0.42, blue: 0.55).opacity(0.10),
        sameDigitHighlight: Color(red: 0.35, green: 0.42, blue: 0.55).opacity(0.18),
        conflict: Color(red: 0.85, green: 0.30, blue: 0.30),
        hintHighlight: Color(red: 0.95, green: 0.78, blue: 0.30).opacity(0.40),
        success: Color(red: 0.25, green: 0.60, blue: 0.42),
        textPrimary: Color(red: 0.13, green: 0.15, blue: 0.18),
        textSecondary: Color(red: 0.50, green: 0.53, blue: 0.58),
    )

    private static let slateDark = Theme(
        id: .slate,
        accent: Color(red: 0.62, green: 0.70, blue: 0.82),
        screenBackground: Color(red: 0.09, green: 0.10, blue: 0.11),
        cardBackground: Color(red: 0.15, green: 0.16, blue: 0.18),
        boardBackground: Color(red: 0.15, green: 0.16, blue: 0.18),
        cellBackground: Color(red: 0.15, green: 0.16, blue: 0.18),
        cellBackgroundAlternate: Color(red: 0.20, green: 0.22, blue: 0.25),
        gridLine: Color(red: 0.30, green: 0.32, blue: 0.36),
        gridLineBold: Color(red: 0.58, green: 0.62, blue: 0.68),
        givenText: Color(red: 0.93, green: 0.94, blue: 0.96),
        playerText: Color(red: 0.62, green: 0.70, blue: 0.82),
        noteText: Color(red: 0.55, green: 0.58, blue: 0.63),
        selection: Color(red: 0.62, green: 0.70, blue: 0.82).opacity(0.32),
        relatedHighlight: Color(red: 0.62, green: 0.70, blue: 0.82).opacity(0.12),
        sameDigitHighlight: Color(red: 0.62, green: 0.70, blue: 0.82).opacity(0.20),
        conflict: Color(red: 1.00, green: 0.48, blue: 0.48),
        hintHighlight: Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.35),
        success: Color(red: 0.35, green: 0.75, blue: 0.52),
        textPrimary: Color(red: 0.93, green: 0.94, blue: 0.96),
        textSecondary: Color(red: 0.60, green: 0.63, blue: 0.68),
    )

    private static let forestLight = Theme(
        id: .forest,
        accent: Color(red: 0.16, green: 0.55, blue: 0.38),
        screenBackground: Color(red: 0.95, green: 0.97, blue: 0.95),
        cardBackground: .white,
        boardBackground: .white,
        cellBackground: .white,
        cellBackgroundAlternate: Color(red: 0.90, green: 0.95, blue: 0.91),
        gridLine: Color(red: 0.74, green: 0.81, blue: 0.76),
        gridLineBold: Color(red: 0.22, green: 0.33, blue: 0.27),
        givenText: Color(red: 0.10, green: 0.18, blue: 0.13),
        playerText: Color(red: 0.16, green: 0.55, blue: 0.38),
        noteText: Color(red: 0.45, green: 0.54, blue: 0.48),
        selection: Color(red: 0.16, green: 0.55, blue: 0.38).opacity(0.28),
        relatedHighlight: Color(red: 0.16, green: 0.55, blue: 0.38).opacity(0.10),
        sameDigitHighlight: Color(red: 0.16, green: 0.55, blue: 0.38).opacity(0.18),
        conflict: Color(red: 0.85, green: 0.30, blue: 0.25),
        hintHighlight: Color(red: 0.95, green: 0.80, blue: 0.30).opacity(0.40),
        success: Color(red: 0.16, green: 0.55, blue: 0.38),
        textPrimary: Color(red: 0.10, green: 0.18, blue: 0.13),
        textSecondary: Color(red: 0.45, green: 0.54, blue: 0.48),
    )

    private static let forestDark = Theme(
        id: .forest,
        accent: Color(red: 0.40, green: 0.80, blue: 0.60),
        screenBackground: Color(red: 0.06, green: 0.10, blue: 0.08),
        cardBackground: Color(red: 0.11, green: 0.16, blue: 0.13),
        boardBackground: Color(red: 0.11, green: 0.16, blue: 0.13),
        cellBackground: Color(red: 0.11, green: 0.16, blue: 0.13),
        cellBackgroundAlternate: Color(red: 0.15, green: 0.22, blue: 0.18),
        gridLine: Color(red: 0.26, green: 0.34, blue: 0.29),
        gridLineBold: Color(red: 0.50, green: 0.66, blue: 0.56),
        givenText: Color(red: 0.92, green: 0.96, blue: 0.93),
        playerText: Color(red: 0.40, green: 0.80, blue: 0.60),
        noteText: Color(red: 0.52, green: 0.62, blue: 0.56),
        selection: Color(red: 0.40, green: 0.80, blue: 0.60).opacity(0.32),
        relatedHighlight: Color(red: 0.40, green: 0.80, blue: 0.60).opacity(0.12),
        sameDigitHighlight: Color(red: 0.40, green: 0.80, blue: 0.60).opacity(0.20),
        conflict: Color(red: 1.00, green: 0.48, blue: 0.42),
        hintHighlight: Color(red: 0.95, green: 0.80, blue: 0.35).opacity(0.35),
        success: Color(red: 0.40, green: 0.80, blue: 0.60),
        textPrimary: Color(red: 0.92, green: 0.96, blue: 0.93),
        textSecondary: Color(red: 0.55, green: 0.65, blue: 0.59),
    )

    // MARK: - Premium themes

    private static let midnight = Theme(
        id: .midnight,
        accent: Color(red: 0.55, green: 0.45, blue: 1.00),
        screenBackground: Color(red: 0.04, green: 0.04, blue: 0.09),
        cardBackground: Color(red: 0.09, green: 0.09, blue: 0.16),
        boardBackground: Color(red: 0.09, green: 0.09, blue: 0.16),
        cellBackground: Color(red: 0.09, green: 0.09, blue: 0.16),
        cellBackgroundAlternate: Color(red: 0.13, green: 0.13, blue: 0.23),
        gridLine: Color(red: 0.25, green: 0.25, blue: 0.38),
        gridLineBold: Color(red: 0.50, green: 0.48, blue: 0.72),
        givenText: Color(red: 0.93, green: 0.92, blue: 1.00),
        playerText: Color(red: 0.55, green: 0.45, blue: 1.00),
        noteText: Color(red: 0.55, green: 0.55, blue: 0.70),
        selection: Color(red: 0.55, green: 0.45, blue: 1.00).opacity(0.35),
        relatedHighlight: Color(red: 0.55, green: 0.45, blue: 1.00).opacity(0.12),
        sameDigitHighlight: Color(red: 0.55, green: 0.45, blue: 1.00).opacity(0.22),
        conflict: Color(red: 1.00, green: 0.42, blue: 0.55),
        hintHighlight: Color(red: 1.00, green: 0.82, blue: 0.40).opacity(0.35),
        success: Color(red: 0.38, green: 0.85, blue: 0.65),
        textPrimary: Color(red: 0.93, green: 0.92, blue: 1.00),
        textSecondary: Color(red: 0.58, green: 0.58, blue: 0.72),
    )

    private static let roseLight = Theme(
        id: .rose,
        accent: Color(red: 0.85, green: 0.30, blue: 0.45),
        screenBackground: Color(red: 0.99, green: 0.95, blue: 0.96),
        cardBackground: .white,
        boardBackground: .white,
        cellBackground: .white,
        cellBackgroundAlternate: Color(red: 0.98, green: 0.91, blue: 0.93),
        gridLine: Color(red: 0.88, green: 0.76, blue: 0.79),
        gridLineBold: Color(red: 0.45, green: 0.25, blue: 0.30),
        givenText: Color(red: 0.22, green: 0.10, blue: 0.13),
        playerText: Color(red: 0.85, green: 0.30, blue: 0.45),
        noteText: Color(red: 0.60, green: 0.47, blue: 0.50),
        selection: Color(red: 0.85, green: 0.30, blue: 0.45).opacity(0.26),
        relatedHighlight: Color(red: 0.85, green: 0.30, blue: 0.45).opacity(0.10),
        sameDigitHighlight: Color(red: 0.85, green: 0.30, blue: 0.45).opacity(0.16),
        conflict: Color(red: 0.75, green: 0.15, blue: 0.15),
        hintHighlight: Color(red: 0.98, green: 0.80, blue: 0.35).opacity(0.40),
        success: Color(red: 0.22, green: 0.62, blue: 0.45),
        textPrimary: Color(red: 0.22, green: 0.10, blue: 0.13),
        textSecondary: Color(red: 0.60, green: 0.47, blue: 0.50),
    )

    private static let roseDark = Theme(
        id: .rose,
        accent: Color(red: 1.00, green: 0.55, blue: 0.66),
        screenBackground: Color(red: 0.11, green: 0.06, blue: 0.08),
        cardBackground: Color(red: 0.17, green: 0.11, blue: 0.13),
        boardBackground: Color(red: 0.17, green: 0.11, blue: 0.13),
        cellBackground: Color(red: 0.17, green: 0.11, blue: 0.13),
        cellBackgroundAlternate: Color(red: 0.23, green: 0.15, blue: 0.18),
        gridLine: Color(red: 0.38, green: 0.28, blue: 0.31),
        gridLineBold: Color(red: 0.72, green: 0.52, blue: 0.57),
        givenText: Color(red: 0.98, green: 0.93, blue: 0.94),
        playerText: Color(red: 1.00, green: 0.55, blue: 0.66),
        noteText: Color(red: 0.68, green: 0.55, blue: 0.58),
        selection: Color(red: 1.00, green: 0.55, blue: 0.66).opacity(0.32),
        relatedHighlight: Color(red: 1.00, green: 0.55, blue: 0.66).opacity(0.12),
        sameDigitHighlight: Color(red: 1.00, green: 0.55, blue: 0.66).opacity(0.20),
        conflict: Color(red: 1.00, green: 0.40, blue: 0.35),
        hintHighlight: Color(red: 0.98, green: 0.80, blue: 0.40).opacity(0.35),
        success: Color(red: 0.35, green: 0.78, blue: 0.55),
        textPrimary: Color(red: 0.98, green: 0.93, blue: 0.94),
        textSecondary: Color(red: 0.68, green: 0.55, blue: 0.58),
    )

    private static let amberLight = Theme(
        id: .amber,
        accent: Color(red: 0.80, green: 0.52, blue: 0.10),
        screenBackground: Color(red: 0.99, green: 0.97, blue: 0.92),
        cardBackground: .white,
        boardBackground: .white,
        cellBackground: .white,
        cellBackgroundAlternate: Color(red: 0.98, green: 0.94, blue: 0.85),
        gridLine: Color(red: 0.86, green: 0.80, blue: 0.68),
        gridLineBold: Color(red: 0.42, green: 0.33, blue: 0.18),
        givenText: Color(red: 0.20, green: 0.15, blue: 0.06),
        playerText: Color(red: 0.80, green: 0.52, blue: 0.10),
        noteText: Color(red: 0.58, green: 0.52, blue: 0.42),
        selection: Color(red: 0.80, green: 0.52, blue: 0.10).opacity(0.26),
        relatedHighlight: Color(red: 0.80, green: 0.52, blue: 0.10).opacity(0.10),
        sameDigitHighlight: Color(red: 0.80, green: 0.52, blue: 0.10).opacity(0.16),
        conflict: Color(red: 0.82, green: 0.25, blue: 0.20),
        hintHighlight: Color(red: 0.95, green: 0.75, blue: 0.25).opacity(0.45),
        success: Color(red: 0.30, green: 0.60, blue: 0.35),
        textPrimary: Color(red: 0.20, green: 0.15, blue: 0.06),
        textSecondary: Color(red: 0.58, green: 0.52, blue: 0.42),
    )

    private static let amberDark = Theme(
        id: .amber,
        accent: Color(red: 1.00, green: 0.72, blue: 0.30),
        screenBackground: Color(red: 0.10, green: 0.08, blue: 0.05),
        cardBackground: Color(red: 0.16, green: 0.13, blue: 0.09),
        boardBackground: Color(red: 0.16, green: 0.13, blue: 0.09),
        cellBackground: Color(red: 0.16, green: 0.13, blue: 0.09),
        cellBackgroundAlternate: Color(red: 0.22, green: 0.18, blue: 0.12),
        gridLine: Color(red: 0.36, green: 0.31, blue: 0.23),
        gridLineBold: Color(red: 0.68, green: 0.58, blue: 0.42),
        givenText: Color(red: 0.98, green: 0.95, blue: 0.90),
        playerText: Color(red: 1.00, green: 0.72, blue: 0.30),
        noteText: Color(red: 0.66, green: 0.60, blue: 0.50),
        selection: Color(red: 1.00, green: 0.72, blue: 0.30).opacity(0.30),
        relatedHighlight: Color(red: 1.00, green: 0.72, blue: 0.30).opacity(0.12),
        sameDigitHighlight: Color(red: 1.00, green: 0.72, blue: 0.30).opacity(0.20),
        conflict: Color(red: 1.00, green: 0.45, blue: 0.38),
        hintHighlight: Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.38),
        success: Color(red: 0.42, green: 0.78, blue: 0.50),
        textPrimary: Color(red: 0.98, green: 0.95, blue: 0.90),
        textSecondary: Color(red: 0.66, green: 0.60, blue: 0.50),
    )
}
