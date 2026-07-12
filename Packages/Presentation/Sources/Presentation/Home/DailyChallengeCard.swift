import Common
import Foundation
import Model
import SwiftUI

/// The daily challenge card: today's plan, countdown, completion state, and
/// the current streak flame.
struct DailyChallengeCard: View {
    let dailyState: ViewState<DailyChallenge>
    let dailyStreak: Int
    let onTap: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        Button(action: onTap) {
            CardView {
                HStack(spacing: 14) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("home.daily.title", bundle: .module)
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            if dailyStreak > 0 {
                                Label {
                                    Text("\(dailyStreak)")
                                        .monospacedDigit()
                                } icon: {
                                    Image(systemName: "flame.fill")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                                .accessibilityLabel(String(
                                    format: String(localized: "a11y.streak", bundle: .module),
                                    dailyStreak,
                                ))
                            }
                        }
                        subtitle(theme: theme)
                    }
                    Spacer()
                    trailing(theme: theme)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(dailyState.value == nil)
    }

    @ViewBuilder
    private func subtitle(theme: Theme) -> some View {
        switch dailyState {
        case .idle, .loading:
            Text("home.daily.loading", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        case let .loaded(daily):
            HStack(spacing: 6) {
                Text(verbatim: moduleString("variant.\(daily.puzzle.variant.slug)"))
                Text("·")
                Text(verbatim: moduleString(
                    "difficulty.\(daily.puzzle.requestedDifficulty.slug)",
                ))
                Text("·")
                CountdownText(until: daily.endsAt)
            }
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
        case .empty, .failed:
            Text("home.daily.unavailable", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    @ViewBuilder
    private func trailing(theme: Theme) -> some View {
        if let daily = dailyState.value, daily.isCompleted {
            VStack(spacing: 2) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(theme.success)
                if let time = daily.completionTime {
                    Text(DurationFormatter.string(for: time))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
            }
        } else {
            Image(systemName: "chevron.right")
                .foregroundStyle(theme.textSecondary)
        }
    }
}
