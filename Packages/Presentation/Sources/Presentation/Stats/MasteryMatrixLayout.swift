import Model

/// One variant's line of the mastery matrix: its cells in difficulty order.
struct MasteryRow: Identifiable, Equatable {
    let variant: SudokuVariant
    let cells: [VariantStats]

    var id: SudokuVariant {
        variant
    }

    func cell(for difficulty: Difficulty) -> VariantStats? {
        cells.first { $0.difficulty == difficulty }
    }

    var isTouched: Bool {
        cells.contains { $0.played > 0 }
    }
}

/// Splits the grid into the rows a free player keeps and the rows the paywall
/// hides. Any record counts as touching a variant, so a daily-challenge win
/// keeps its row live after the variant leaves the free lineup.
struct MasteryMatrixLayout: Equatable {
    let rows: [MasteryRow]

    init(overview: StatsOverview) {
        let byVariant = Dictionary(grouping: overview.perVariant, by: \.variant)
        rows = SudokuVariant.allCases.map { variant in
            MasteryRow(
                variant: variant,
                cells: (byVariant[variant] ?? []).sorted { $0.difficulty < $1.difficulty },
            )
        }
    }

    var touched: [MasteryRow] {
        rows.filter(\.isTouched)
    }

    var locked: [MasteryRow] {
        rows.filter { !$0.isTouched }
    }
}

extension VariantStats {
    /// The matrix badge: at least one win with no mistakes and no hints.
    var hasPerfectSolve: Bool {
        perfectSolves > 0
    }
}
