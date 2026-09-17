import Charts
import Foundation
import Model
import SwiftUI

/// The stats screen's breakdown cards: 30-day activity, classic win rate per
/// difficulty, classic best vs average times, and variant distribution.
struct StatsChartsView: View {
    let overview: StatsOverview

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let slices = variantSlices
        VStack(spacing: 16) {
            if hasRecentActivity {
                ActivityChartView(days: overview.gamesPerDay)
            }

            if !overview.classicWinRateByDifficulty.isEmpty {
                WinRateBreakdownView(entries: overview.classicWinRateByDifficulty)
            }

            ClassicTimesCards(overview: overview)

            if !slices.isEmpty {
                chartCard("stats.chart.variants") {
                    Chart(slices) { slice in
                        SectorMark(
                            angle: .value("Games", slice.played),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5,
                        )
                        .foregroundStyle(by: .value("Variant", slice.name))
                        .cornerRadius(3)
                    }
                    .chartForegroundStyleScale(
                        domain: slices.map(\.name),
                        range: StatsPalette.series(count: slices.count, theme: theme),
                    )
                    .frame(height: 200)
                }
            }
        }
    }

    /// The seven most played variants, then everything else pooled into one
    /// sector: past eight colours the legend can no longer be matched to the
    /// chart, and 25 slivers read as noise either way.
    private var variantSlices: [VariantSlice] {
        let ranked = overview.variantShares
            .sorted { $0.played > $1.played }
            .map { VariantSlice(name: localizedVariant($0.variant), played: $0.played) }
        guard ranked.count > VariantSlice.maximum else { return ranked }
        let pooled = ranked.dropFirst(VariantSlice.maximum - 1).reduce(0) { $0 + $1.played }
        return ranked.prefix(VariantSlice.maximum - 1) + [VariantSlice(
            name: moduleString("stats.chart.variants.other"),
            played: pooled,
        )]
    }

    /// `gamesPerDay` is zero-filled to exactly 30 entries, so it is never
    /// empty — unlike its sibling series, the card has to check the counts.
    private var hasRecentActivity: Bool {
        overview.gamesPerDay.contains { $0.count >= 1 }
    }

    private func chartCard(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder chart: () -> some View,
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(titleKey)
                chart()
            }
        }
    }

    private func localizedVariant(_ variant: SudokuVariant) -> String {
        moduleString("variant.\(variant.slug)")
    }
}

/// One sector of the variant donut: a variant, or the pooled remainder.
private struct VariantSlice: Identifiable {
    static let maximum = 8

    let name: String
    let played: Int

    var id: String {
        name
    }
}
