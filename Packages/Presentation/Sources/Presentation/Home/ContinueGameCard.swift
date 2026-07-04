import Foundation
import Model
import SwiftUI

/// The "pick up where you left off" card.
struct ContinueGameCard: View {
    let saved: SavedGame
    let onTap: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        Button(action: onTap) {
            CardView {
                HStack(spacing: 14) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("home.continue.title", bundle: .module)
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        HStack(spacing: 6) {
                            Text(verbatim: moduleString(
                                "variant.\(saved.puzzle.variant.slug)",
                            ))
                            Text("·")
                            Text(verbatim: moduleString(
                                "difficulty.\(saved.puzzle.requestedDifficulty.slug)",
                            ))
                            Text("·")
                            Text(DurationFormatter.string(for: saved.elapsed))
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        progressBar(theme: theme)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func progressBar(theme: Theme) -> some View {
        let progress = Double(saved.board.filledCount) / Double(max(1, saved.board.count))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.cellBackgroundAlternate)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 5)
        .accessibilityLabel(String(
            format: String(localized: "a11y.progress", bundle: .module),
            Int(progress * 100),
        ))
    }
}
