import Domain
import Foundation
import Model
import SwiftUI

/// End-of-game card: victory (with confetti behind, driven by the parent) or
/// hardcore defeat, plus stats, badges, and exit actions.
struct CompletionView: View {
    let summary: CompletionSummary
    let onNewGame: () -> Void
    let onHome: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let won = summary.outcome == .won

        VStack(spacing: 18) {
            Image(systemName: won ? "trophy.fill" : "heart.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(won ? theme.success : theme.conflict)
                .symbolEffect(.bounce, value: won)
                .accessibilityHidden(true)

            Text(won ? "game.finished.won" : "game.finished.lost", bundle: .module)
                .font(.title.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            if summary.isPersonalBest {
                Label {
                    Text("game.finished.personalBest", bundle: .module)
                } icon: {
                    Image(systemName: "sparkles")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
            }

            HStack(spacing: 10) {
                StatTile(
                    "game.finished.time",
                    value: DurationFormatter.string(for: summary.duration),
                )
                StatTile("game.finished.mistakes", value: "\(summary.mistakes)")
                StatTile("game.finished.hints", value: "\(summary.hintsUsed)")
            }

            if summary.tournamentPoints > 0 {
                Text(
                    String(
                        format: String(localized: "game.finished.points", bundle: .module),
                        summary.tournamentPoints,
                    ),
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
            }

            if !summary.earnedAchievements.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.earnedAchievements, id: \.rawValue) { achievement in
                        Label {
                            Text(verbatim: moduleString(
                                "achievement.\(achievement.rawValue)",
                            ))
                        } icon: {
                            Image(systemName: "rosette")
                        }
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            VStack(spacing: 10) {
                PrimaryButton("game.finished.newGame", systemImage: "plus") {
                    onNewGame()
                }
                Button {
                    onHome()
                } label: {
                    Text("game.finished.home", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textPrimary)
            }
            .frame(maxWidth: 280)
        }
        .padding(28)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 24)
        .padding(24)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}
