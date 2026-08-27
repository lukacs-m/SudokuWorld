import Common
import Foundation
import Model
import SwiftUI

/// The daily lineup card: the day's three challenges with their completion
/// state, the countdown, and the current streak flame.
struct DailyChallengeCard: View {
    let dailyState: ViewState<DailyLineup>
    let dailyStreak: Int
    let onPlay: (DailyLineup.Slot) -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                header(theme: theme)
                content(theme: theme)
            }
        }
    }

    private func header(theme: Theme) -> some View {
        HStack(spacing: 8) {
            SectionLabel("home.daily.title")
            if dailyStreak > 0 {
                Label {
                    Text("\(dailyStreak)")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "flame.fill")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.753, green: 0.600, blue: 0.294))
                .accessibilityLabel(String(
                    format: String(localized: "a11y.streak", bundle: .module),
                    dailyStreak,
                ))
            }
            Spacer()
            if let lineup = dailyState.value {
                CountdownText(until: lineup.endsAt)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func content(theme: Theme) -> some View {
        switch dailyState {
        case .idle, .loading:
            Text("home.daily.loading", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

        case let .loaded(lineup):
            ForEach(lineup.slots, id: \.variant) { slot in
                DailySlotRow(slot: slot, theme: theme) {
                    onPlay(slot)
                }
                if slot != lineup.slots.last {
                    Divider()
                }
            }

        case .empty, .failed:
            Text("home.daily.unavailable", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

/// One tappable lineup row: variant and difficulty, with a completion badge
/// (and best time) once solved.
struct DailySlotRow: View {
    let slot: DailyLineup.Slot
    let theme: Theme
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: moduleString("variant.\(slot.variant.slug)"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    Text(verbatim: moduleString("difficulty.\(slot.difficulty.slug)"))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if slot.isCompleted {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(theme.success)
                            .accessibilityLabel(Text("events.daily.doneNoTime", bundle: .module))
                        if let time = slot.completionTime {
                            Text(DurationFormatter.string(for: time))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
