import Common
import Model
import SwiftUI

/// Leaderboard standings: top entries plus the local player's rank.
struct StandingsListView: View {
    let standings: ViewState<LeaderboardStandings>
    let authState: GameCenterAuthState

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            switch (authState, standings) {
            case (.authenticated, .loading), (.authenticated, .idle):
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

            case let (.authenticated, .loaded(board)):
                ForEach(board.entries) { entry in
                    row(entry, theme: theme)
                }
                if let local = board.localEntry,
                   !board.entries.contains(where: \.isLocalPlayer)
                {
                    Divider()
                    row(local, theme: theme)
                }

            case (.authenticated, .empty):
                Text("events.standings.empty", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)

            case (.authenticated, .failed):
                Text("events.standings.error", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)

            default:
                Label {
                    Text("events.signInPrompt", bundle: .module)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                }
                .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func row(_ entry: LeaderboardStandings.Entry, theme: Theme) -> some View {
        HStack(spacing: 10) {
            Text("#\(entry.rank)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(entry.rank <= 3 ? theme.accent : theme.textSecondary)
                .frame(width: 42, alignment: .leading)
            Text(entry.displayName)
                .font(.subheadline.weight(entry.isLocalPlayer ? .bold : .regular))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
            if entry.isLocalPlayer {
                Text("events.you", bundle: .module)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(theme.accent)
            }
            Spacer()
            Text(entry.scoreText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(theme.textSecondary)
        }
    }
}
