import Foundation
import Model
import SwiftUI

/// The "pick up where you left off" card: progress line, bar, and an
/// embedded resume button — the home screen's primary call to action.
struct ContinueGameCard: View {
    let saved: SavedGame
    let onTap: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        Double(saved.board.filledCount) / Double(max(1, saved.board.count))
    }

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("home.continue.title")
                HStack(spacing: 6) {
                    Text(verbatim: moduleString("variant.\(saved.puzzle.variant.slug)"))
                    Text("·")
                    Text(verbatim: moduleString(
                        "difficulty.\(saved.puzzle.requestedDifficulty.slug)",
                    ))
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                Text(
                    String(
                        format: String(localized: "home.continue.progress", bundle: .module),
                        Int(progress * 100),
                        DurationFormatter.string(for: saved.elapsed),
                    ),
                )
                .monospacedDigit()
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                progressBar(theme: theme)
                PrimaryButton("home.continue.resume", systemImage: "play.fill") {
                    onTap()
                }
                .padding(.top, 4)
            }
        }
    }

    private func progressBar(theme: Theme) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.cellBackgroundAlternate)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 6)
        .accessibilityLabel(String(
            format: String(localized: "a11y.progress", bundle: .module),
            Int(progress * 100),
        ))
    }
}
