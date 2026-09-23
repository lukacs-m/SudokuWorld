import Foundation
import Model
import SwiftUI

/// Per-variant results, one row per variant played, each opening that
/// variant's deep dive.
struct VariantBreakdownView: View {
    let overview: StatsOverview

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("stats.byVariant")
                ForEach(sections, id: \.variant) { section in
                    VariantBreakdownRow(
                        variant: section.variant,
                        cells: section.cells,
                        overview: overview,
                    )
                    if section.variant != sections.last?.variant {
                        Divider()
                    }
                }
            }
        }
    }

    /// The grid keeps empty cells for the mastery matrix; this list only
    /// shows what was actually played.
    private var sections: [(variant: SudokuVariant, cells: [VariantStats])] {
        let played = overview.perVariant.filter { $0.played > 0 }
        let byVariant = Dictionary(grouping: played, by: \.variant)
        return SudokuVariant.allCases.compactMap { variant in
            byVariant[variant].map { (variant, $0) }
        }
    }
}

private struct VariantBreakdownRow: View {
    let variant: SudokuVariant
    let cells: [VariantStats]
    let overview: StatsOverview

    @Environment(StatsRouter.self) private var router
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        Button {
            router.push(.variantDetail(variant, overview))
        } label: {
            HStack(spacing: 10) {
                Text(verbatim: moduleString("variant.\(variant.slug)"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: wonPlayedString(won: totalWon, played: totalPlayed))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.textPrimary)
                    if let best = bestTime {
                        Text(verbatim: overAllBestTimeString(best))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var totalWon: Int {
        cells.reduce(0) { $0 + $1.won }
    }

    private var totalPlayed: Int {
        cells.reduce(0) { $0 + $1.played }
    }

    private var bestTime: TimeInterval? {
        cells.compactMap(\.fastestTime).min()
    }
}

/// "26/26 won" — the bare ratio confused testers, so the unit is spelled out.
func wonPlayedString(won: Int, played: Int) -> String {
    String(
        format: String(localized: "stats.variant.wonPlayed", bundle: .module),
        won,
        played,
    )
}

/// "Best 3:00", matching the "Avg %@" idiom of the Best times card.
func bestTimeString(_ time: TimeInterval) -> String {
    String(
        format: String(localized: "stats.variant.best", bundle: .module),
        DurationFormatter.string(for: time),
    )
}

/// "Best 3:00", matching the "Avg %@" idiom of the Best times card.
private func overAllBestTimeString(_ time: TimeInterval) -> String {
    String(
        format: String(localized: "overAllBest", bundle: .module),
        DurationFormatter.string(for: time),
    )
}
