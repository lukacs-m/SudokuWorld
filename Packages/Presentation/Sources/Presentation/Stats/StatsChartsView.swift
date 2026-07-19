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
                    VStack(spacing: 0) {
                        ForEach(overview.timesByDifficulty) { entry in
                            timesRow(entry, theme: theme)
                            if entry.id != overview.timesByDifficulty.last?.id {
                                Divider()
                            }
                        }
                    }
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
        theme _: Theme,
        @ViewBuilder chart: () -> some View,
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(titleKey)
                chart()
            }
        }
    }

    /// The mock's best-times row: difficulty left, best bold with average
    /// underneath on the right.
    private func timesRow(_ entry: StatsOverview.DifficultyTimes, theme: Theme) -> some View {
        HStack {
            Text(verbatim: localizedDifficulty(entry.difficulty))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let fastest = entry.fastest {
                    Text(DurationFormatter.string(for: fastest))
                        .font(.headline)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                }
                if let average = entry.average {
                    Text(
                        String(
                            format: String(localized: "stats.times.average", bundle: .module),
                            DurationFormatter.string(for: average),
                        ),
                    )
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func localizedDifficulty(_ difficulty: Difficulty) -> String {
        moduleString("difficulty.\(difficulty.slug)")
    }

    private func localizedVariant(_ variant: SudokuVariant) -> String {
        moduleString("variant.\(variant.slug)")
    }
}
