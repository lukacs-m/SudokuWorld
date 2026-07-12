/// The catalog sections variants are grouped under; declaration order is
/// display order. Raw values are stable slugs used to build localization keys.
public enum SudokuVariantGroup: String, CaseIterable, Equatable, Sendable, Codable {
    case gridSizes = "gridsizes"
    case extraRegions = "extraregions"
    case relationClues = "relationclues"
    case chess
    case multiGrid = "multigrid"
    case twists

    /// Stable identifier used in localization keys.
    public var slug: String {
        rawValue
    }
}
