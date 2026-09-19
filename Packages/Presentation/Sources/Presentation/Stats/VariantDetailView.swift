import Domain
import Foundation
import Model
import SwiftUI

/// Item 9 of the stats plan: one variant in depth. Outcome counts, every
/// difficulty's record, and the variant's own solve-time trend.
struct VariantDetailView: View {
    let variant: SudokuVariant
    let overview: StatsOverview

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let cells = overview.perVariant
            .filter { $0.variant == variant }
            .sorted { $0.difficulty < $1.difficulty }
        ScrollView {
            VStack(spacing: 16) {
                VariantOutcomeGrid(cells: cells)
                VariantDifficultyCard(cells: cells)
                SolveTimeTrendSection(options: [trendOption])
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text(verbatim: moduleString("variant.\(variant.slug)")))
    }

    /// A variant with no win in the last 90 days has no series; an empty one
    /// keeps the card and its empty-state line on screen.
    private var trendOption: TrendSeriesOption {
        TrendSeriesOption(
            id: .variant(variant),
            trend: overview.solveTimeTrendByVariant[variant]
                ?? StatsOverview.SolveTimeTrend(
                    endDay: EventSeeds.utcCalendar.startOfDay(for: Date()),
                    last7Days: [],
                    last30Days: [],
                    last90Days: [],
                ),
        )
    }
}

private struct VariantOutcomeGrid: View {
    let cells: [VariantStats]

    @ScaledMetric(relativeTo: .caption) private var tileMinimum: CGFloat = 100

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 10)],
            spacing: 10,
        ) {
            StatTile("stats.won", value: "\(cells.reduce(0) { $0 + $1.won })")
            StatTile("stats.lost", value: "\(cells.reduce(0) { $0 + $1.lost })")
            StatTile("stats.variant.abandoned", value: "\(cells.reduce(0) { $0 + $1.abandoned })")
        }
    }
}

/// One row per difficulty the variant offers (or once offered): won over
/// played on the left, best and average time on the right, dashes where the
/// tier has no games yet. Analysis rather than motivation, so free players
/// see it blurred; the outcome tiles above stay theirs.
struct VariantDifficultyCard: View {
    let cells: [VariantStats]

    var body: some View {
        PremiumStatBlurOverlay(
            "stats.premium.variantTimes.title",
            tease: "stats.premium.variantTimes.tease",
        ) {
            VariantDifficultyRows(cells: cells)
        }
    }
}

struct VariantDifficultyRows: View {
    let cells: [VariantStats]

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("stats.variant.byDifficulty")
            VStack(spacing: 0) {
                ForEach(cells, id: \.difficulty) { cell in
                    VariantDifficultyRow(stats: cell, theme: theme)
                    if cell.difficulty != cells.last?.difficulty {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct VariantDifficultyRow: View {
    let stats: VariantStats
    let theme: Theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: moduleString("difficulty.\(stats.difficulty.slug)"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                Text(verbatim: stats.played > 0
                    ? wonPlayedString(won: stats.won, played: stats.played)
                    : "-")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: stats.fastestTime.map(DurationFormatter.string(for:)) ?? "-")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                Text(verbatim: stats.averageTime.map(averageTimeString) ?? "-")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func averageTimeString(_ time: TimeInterval) -> String {
        String(
            format: String(localized: "stats.times.average", bundle: .module),
            DurationFormatter.string(for: time),
        )
    }
}

#Preview("Free") {
    NavigationStack {
        VariantDetailView(variant: .killer, overview: .masteryPreview)
    }
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: false))
}

#Preview("Premium") {
    NavigationStack {
        VariantDetailView(variant: .classic, overview: .masteryPreview)
    }
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: true))
}
