public import Model
public import SwiftUI

/// The color roles every screen draws with. Palettes (light/dark pairs per
/// `ThemeID`) live in `ThemePalettes`; views resolve one `Theme` from the
/// store and the current color scheme.
public struct Theme: Equatable, Sendable {
    public let id: ThemeID

    public let accent: Color
    public let screenBackground: Color
    public let cardBackground: Color

    public let boardBackground: Color
    public let cellBackground: Color
    /// Alternating box shading (and windoku windows).
    public let cellBackgroundAlternate: Color
    public let gridLine: Color
    public let gridLineBold: Color

    public let givenText: Color
    public let playerText: Color
    public let noteText: Color

    public let selection: Color
    public let relatedHighlight: Color
    public let sameDigitHighlight: Color
    public let conflict: Color
    public let hintHighlight: Color

    public let success: Color
    public let textPrimary: Color
    public let textSecondary: Color

    public init(
        id: ThemeID,
        accent: Color,
        screenBackground: Color,
        cardBackground: Color,
        boardBackground: Color,
        cellBackground: Color,
        cellBackgroundAlternate: Color,
        gridLine: Color,
        gridLineBold: Color,
        givenText: Color,
        playerText: Color,
        noteText: Color,
        selection: Color,
        relatedHighlight: Color,
        sameDigitHighlight: Color,
        conflict: Color,
        hintHighlight: Color,
        success: Color,
        textPrimary: Color,
        textSecondary: Color,
    ) {
        self.id = id
        self.accent = accent
        self.screenBackground = screenBackground
        self.cardBackground = cardBackground
        self.boardBackground = boardBackground
        self.cellBackground = cellBackground
        self.cellBackgroundAlternate = cellBackgroundAlternate
        self.gridLine = gridLine
        self.gridLineBold = gridLineBold
        self.givenText = givenText
        self.playerText = playerText
        self.noteText = noteText
        self.selection = selection
        self.relatedHighlight = relatedHighlight
        self.sameDigitHighlight = sameDigitHighlight
        self.conflict = conflict
        self.hintHighlight = hintHighlight
        self.success = success
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
    }
}
