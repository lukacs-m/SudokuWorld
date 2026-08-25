import Foundation
import Model
import SwiftUI

/// Per-variant results, one collapsible section per variant played, each
/// holding that variant's difficulty breakdown.
struct VariantBreakdownView: View {
    let overview: StatsOverview

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("stats.byVariant")
                ForEach(sections, id: \.variant) { section in
                    VariantBreakdownSection(variant: section.variant, cells: section.cells)
                    if section.variant != sections.last?.variant {
                        Divider()
                    }
                }
            }
        }
    }

    private var sections: [(variant: SudokuVariant, cells: [VariantStats])] {
        let byVariant = Dictionary(grouping: overview.perVariant, by: \.variant)
        return SudokuVariant.allCases.compactMap { variant in
            byVariant[variant].map { (variant, $0) }
        }
    }
}

private struct VariantBreakdownSection: View {
    let variant: SudokuVariant
    let cells: [VariantStats]

    @State private var isExpanded = false

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(spacing: 0) {
            // A plain `DisclosureGroup` here never toggles — its style expects a
            // `List` row. A button keeps the whole header as the hit target.
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                header(theme: theme)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(cells, id: \.difficulty) { cell in
                    VariantDifficultyRow(stats: cell, theme: theme)
                }
            }
        }
    }

    private func header(theme: Theme) -> some View {
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
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
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

private struct VariantDifficultyRow: View {
    let stats: VariantStats
    let theme: Theme

    var body: some View {
        HStack {
            Text(verbatim: moduleString("difficulty.\(stats.difficulty.slug)"))
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: wonPlayedString(won: stats.won, played: stats.played))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.textPrimary)
                if let fastest = stats.fastestTime {
                    Text(verbatim: bestTimeString(fastest))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.leading, 12)
    }
}

/// "26/26 won" — the bare ratio confused testers, so the unit is spelled out.
private func wonPlayedString(won: Int, played: Int) -> String {
    String(
        format: String(localized: "stats.variant.wonPlayed", bundle: .module),
        won,
        played,
    )
}

/// "Best 3:00", matching the "Avg %@" idiom of the Best times card.
private func bestTimeString(_ time: TimeInterval) -> String {
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
