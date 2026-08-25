import Foundation
import Model
import SwiftUI

/// The mock's streak card: current streak large, best-ever underneath, one
/// row for the daily streak and one for the win streak.
struct StreakBadgeView: View {
    let streaks: StreakInfo

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        CardView {
            VStack(spacing: 12) {
                row(
                    label: "stats.streak.daily",
                    best: String(
                        format: String(localized: "stats.streak.bestDays", bundle: .module),
                        streaks.bestDailyStreak,
                    ),
                    value: streaks.currentDailyStreak,
                    systemImage: "flame.fill",
                    theme: theme,
                )
                Divider()
                row(
                    label: "stats.streak.win",
                    best: String(
                        format: String(localized: "stats.streak.bestCount", bundle: .module),
                        streaks.bestWinStreak,
                    ),
                    value: streaks.currentWinStreak,
                    systemImage: "trophy.fill",
                    theme: theme,
                )
            }
        }
    }

    private func row(
        label: LocalizedStringKey,
        best: String,
        value: Int,
        systemImage: String,
        theme: Theme,
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(label)
                Text(best)
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.753, green: 0.600, blue: 0.294))
                    .accessibilityHidden(true)
                Text("\(value)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
            }
        }
    }
}
