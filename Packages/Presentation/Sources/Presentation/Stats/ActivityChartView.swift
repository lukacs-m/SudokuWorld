import Charts
import Foundation
import Model
import SwiftUI

/// The 30-day activity chart. Axis labels land only on interior ticks (the
/// domain is padded half a day per side), which keeps them clear of the
/// chart frame's clipping edges.
struct ActivityChartView: View {
    let days: [StatsOverview.DailyCount]

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel("stats.chart.activity")
                    Spacer()
                    Text("stats.chart.activity.unit", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                chart(theme: theme)
            }
        }
    }

    private func chart(theme: Theme) -> some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("Games", day.count),
                width: .ratio(0.62),
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [theme.accent, theme.accent.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom,
                ),
            )
            .cornerRadius(3)
        }
        .chartXScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: xTicks) {
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(theme.gridLine)
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(height: 160)
    }

    /// Half a day of padding either side so the first and last bars — and their
    /// labels — are not flush against the plot edge.
    private var domain: ClosedRange<Date> {
        let halfDay: TimeInterval = 43200
        guard let first = days.first?.day, let last = days.last?.day else {
            return Date() ... Date()
        }
        return first.addingTimeInterval(-halfDay) ... last.addingTimeInterval(halfDay)
    }

    /// Weekly ticks pulled in from both edges — a `.stride` puts the last
    /// tick close enough to the trailing edge that its label truncates.
    private var xTicks: [Date] {
        [2, 9, 16, 23].compactMap { days.indices.contains($0) ? days[$0].day : nil }
    }

    /// Explicit whole-number ticks; `.automatic` happily labels half a game.
    private var yTicks: [Int] {
        let peak = max(days.map(\.count).max() ?? 0, 1)
        return peak <= 2 ? [0, peak] : [0, peak / 2, peak]
    }
}
