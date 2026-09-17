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
        VStack(spacing: 16) {
            if hasRecentActivity {
                ActivityChartView(days: overview.gamesPerDay)
            }

            if !overview.classicWinRateByDifficulty.isEmpty {
                WinRateBreakdownView(entries: overview.classicWinRateByDifficulty)
            }

            ClassicTimesCards(overview: overview)

            if !overview.variantShares.isEmpty {
                chartCard("stats.chart.variants") {
                    Chart(overview.variantShares) { share in
                        SectorMark(
                            angle: .value("Games", share.played),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5,
                        )
                        .foregroundStyle(by: .value(
                            "Variant",
                            localizedVariant(share.variant),
                        ))
                        .cornerRadius(3)
                    }
                    .chartForegroundStyleScale(
                        domain: overview.variantShares.map { localizedVariant($0.variant) },
                        range: StatsPalette.series(
                            count: overview.variantShares.count,
                            theme: theme,
                        ),
                    )
                    .frame(height: 200)
                }
            }
        }
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
