import SwiftUI

/// Full-board pause cover: hides the grid (no cheating by pausing), shows
/// the clock state, and offers resume / save-and-exit / abandon.
struct PauseOverlayView: View {
    let elapsedText: String
    let onResume: () -> Void
    let onSaveAndExit: () -> Void
    let onAbandon: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(spacing: 20) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text("game.paused.title", bundle: .module)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.textPrimary)
            Text(elapsedText)
                .font(.title3.monospacedDigit())
                .foregroundStyle(theme.textSecondary)

            VStack(spacing: 10) {
                PrimaryButton("game.paused.resume", systemImage: "play.fill") {
                    onResume()
                }
                Button {
                    onSaveAndExit()
                } label: {
                    Text("game.paused.saveExit", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textPrimary)
                Button(role: .destructive) {
                    onAbandon()
                } label: {
                    Text("game.paused.abandon", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 280)
        }
        .padding(32)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 24)
        .padding(24)
    }
}
