import Charts
import Foundation
import Model
import SwiftUI

/// The stats screen's charts: 30-day activity, win rate per difficulty,
/// best vs average times, and variant distribution — all Swift Charts.
struct StatsChartsView: View {
    let overview: StatsOverview

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(spacing: 16) {
            chartCard("stats.chart.activity", theme: theme) {
                Chart(overview.gamesPerDay) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Games", day.count),
                    )
                    .foregroundStyle(theme.accent)
                    .cornerRadius(2)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7))
                }
                .frame(height: 140)
            }

            if !overview.winRateByDifficulty.isEmpty {
                chartCard("stats.chart.winRate", theme: theme) {
                    Chart(overview.winRateByDifficulty) { entry in
                        BarMark(
                            x: .value("Rate", entry.rate * 100),
                            y: .value("Difficulty", localizedDifficulty(entry.difficulty)),
                        )
                        .foregroundStyle(theme.accent)
                        .cornerRadius(3)
                        .annotation(position: .trailing) {
                            Text("\(Int(entry.rate * 100))%")
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .chartXScale(domain: 0 ... 100)
                    .frame(height: CGFloat(overview.winRateByDifficulty.count) * 34 + 20)
                }
            }

            if !overview.timesByDifficulty.isEmpty {
                chartCard("stats.chart.times", theme: theme) {
                    Chart(overview.timesByDifficulty) { entry in
                        if let average = entry.average {
                            BarMark(
                                x: .value("Difficulty", localizedDifficulty(entry.difficulty)),
                                y: .value("Average", average / 60),
                            )
                            .foregroundStyle(theme.accent.opacity(0.4))
                            .position(by: .value("Kind", "avg"))
                        }
                        if let fastest = entry.fastest {
                            BarMark(
                                x: .value("Difficulty", localizedDifficulty(entry.difficulty)),
                                y: .value("Fastest", fastest / 60),
                            )
                            .foregroundStyle(theme.accent)
                            .position(by: .value("Kind", "best"))
                        }
                    }
                    .chartYAxisLabel(String(localized: "stats.chart.minutes", bundle: .module))
                    .frame(height: 160)
                }
            }

            if !overview.variantShares.isEmpty {
                chartCard("stats.chart.variants", theme: theme) {
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
                    .frame(height: 200)
                }
            }
        }
    }

    private func chartCard(
        _ titleKey: LocalizedStringKey,
        theme: Theme,
        @ViewBuilder chart: () -> some View,
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(titleKey, bundle: .module)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                chart()
            }
        }
    }

    private func localizedDifficulty(_ difficulty: Difficulty) -> String {
        String(
            localized: String.LocalizationValue("difficulty.\(difficulty.slug)"),
            bundle: .module,
        )
    }

    private func localizedVariant(_ variant: SudokuVariant) -> String {
        String(localized: String.LocalizationValue("variant.\(variant.slug)"), bundle: .module)
    }
}
