import Foundation
import Model
import SwiftUI

/// Unobtrusive banner card for non-game screens. House creatives carry
/// catalog keys (resolved here); real ad-network text passes through
/// verbatim. Hidden entirely for premium players (the caller passes nil).
struct BannerAdView: View {
    let creative: AdCreative
    let onTap: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("ad.label", bundle: .module)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.textSecondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(creative.headline))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(localized(creative.body))
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(localized(creative.callToAction))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
            }
            .padding(12)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func localized(_ keyOrText: String) -> String {
        String(localized: String.LocalizationValue(keyOrText), bundle: .module)
    }
}
