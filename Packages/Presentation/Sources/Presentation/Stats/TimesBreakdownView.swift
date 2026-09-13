import Common
import Foundation
import Model
import SwiftUI

/// Best and average time per difficulty as rows: difficulty left, best bold
/// with the average underneath on the right.
struct TimesBreakdownView: View {
    let title: String
    let entries: [StatsOverview.DifficultyTimes]

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(verbatim: title)
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        TimesRow(entry: entry, theme: theme)
                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct TimesRow: View {
    let entry: StatsOverview.DifficultyTimes
    let theme: Theme

    var body: some View {
        HStack {
            Text(verbatim: moduleString("difficulty.\(entry.difficulty.slug)"))
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
}
