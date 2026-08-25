import Model
import SwiftUI

/// Win rate per difficulty as rows, matching the Best times card rather than
/// the bar chart it replaces.
struct WinRateBreakdownView: View {
    let entries: [StatsOverview.DifficultyWinRate]

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("stats.chart.winRate")
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        WinRateRow(entry: entry, theme: theme)
                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct WinRateRow: View {
    let entry: StatsOverview.DifficultyWinRate
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: moduleString("difficulty.\(entry.difficulty.slug)"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    Text("\(entry.won)/\(entry.played)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Text("\(Int(entry.rate * 100))%")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
            }
            ProgressView(value: entry.rate)
                .tint(theme.accent)
        }
        .padding(.vertical, 8)
    }
}
