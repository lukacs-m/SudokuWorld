import Foundation
import Model
import SwiftUI

/// Between-games interstitial, rendered as a full-screen ZStack overlay (not
/// `fullScreenCover`, which doesn't exist on macOS). The close control stays
/// disabled until the creative's minimum display time passes.
struct InterstitialOverlayView: View {
    let creative: AdCreative
    let onDismiss: () -> Void

    @State private var secondsRemaining: Int
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    init(creative: AdCreative, onDismiss: @escaping () -> Void) {
        self.creative = creative
        self.onDismiss = onDismiss
        _secondsRemaining = State(initialValue: creative.minimumDisplaySeconds)
    }

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("ad.label", bundle: .module)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.textSecondary.opacity(0.2), in: Capsule())
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        if secondsRemaining > 0 {
                            Text("\(secondsRemaining)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(theme.textSecondary)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(secondsRemaining > 0)
                    .accessibilityLabel(Text("common.close", bundle: .module))
                }

                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)

                Text(localized(creative.headline))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(localized(creative.body))
                    .font(.body)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(LocalizedStringKey(creative.callToAction)) {
                    onDismiss()
                }
                .frame(maxWidth: 240)
            }
            .padding(24)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 24))
            .padding(32)
        }
        .task {
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
            }
        }
    }

    /// House creatives carry catalog keys; third-party adapters carry display
    /// text, which passes through unchanged when no catalog entry matches.
    private func localized(_ keyOrText: String) -> String {
        String(localized: String.LocalizationValue(keyOrText), bundle: .module)
    }
}
