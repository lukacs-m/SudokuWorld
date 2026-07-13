import Model

/// Presentation metadata for the type catalog: which variants the sheet
/// surfaces, how they group into sections, and which merchandising badge a
/// card wears. Playability is a compile-time invariant (every enum case has
/// engine support) — this gate only controls what is shown.
enum VariantCatalog {
    /// Merchandising badge on a card's top-right corner.
    enum Badge {
        case popular
        case new

        var titleKey: String {
            switch self {
            case .popular: "badge.popular"
            case .new: "badge.new"
            }
        }
    }

    /// Every variant the catalog currently surfaces.
    static var available: [SudokuVariant] {
        SudokuVariant.allCases
    }

    /// The catalog grouped into display sections, in `SudokuVariantGroup`
    /// declaration order. Groups with no available variants disappear.
    static var sections: [(group: SudokuVariantGroup, variants: [SudokuVariant])] {
        SudokuVariantGroup.allCases.compactMap { group in
            let members = available.filter { $0.group == group }
            return members.isEmpty ? nil : (group, members)
        }
    }

    /// Curated, not derived: badges are merchandising, moved by hand as the
    /// catalog evolves.
    static func badge(for variant: SudokuVariant) -> Badge? {
        if variant == .classic {
            return .popular
        }
        if newVariants.contains(variant) {
            return .new
        }
        return nil
    }

    private static let newVariants: Set<SudokuVariant> = [
        .antiKnight, .antiKing, .alphadoku25,
    ]
}
