import Model
import SwiftUI

/// Wraps a premium-only stat card for free players: the real content stays
/// underneath, blurred and washed out, with a lock, the stat's name and a
/// one-line tease on top. The whole card opens the paywall. Premium players
/// get the content untouched.
struct PremiumStatBlurOverlay<Content: View>: View {
    private let titleKey: LocalizedStringKey
    private let teaseKey: LocalizedStringKey
    private let content: Content

    @State private var showPaywall = false
    @Environment(PremiumGate.self) private var premiumGate
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    init(
        _ titleKey: LocalizedStringKey,
        tease teaseKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content,
    ) {
        self.titleKey = titleKey
        self.teaseKey = teaseKey
        self.content = content()
    }

    var body: some View {
        if premiumGate.isPremium {
            content
        } else {
            Button {
                showPaywall = true
            } label: {
                locked(theme: themeStore.theme(for: colorScheme))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    /// The clip matches `CardView`'s corner radius so the blur stays inside
    /// the card's silhouette.
    private func locked(theme: Theme) -> some View {
        content
            .blur(radius: 5)
            .overlay(theme.screenBackground.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityHidden(true)
            .overlay {
                LockedStatLabel(titleKey: titleKey, teaseKey: teaseKey, theme: theme)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct LockedStatLabel: View {
    let titleKey: LocalizedStringKey
    let teaseKey: LocalizedStringKey
    let theme: Theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text(titleKey, bundle: .module)
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Text(teaseKey, bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(16)
    }
}

#Preview("Free") {
    PremiumStatBlurOverlay(
        "stats.premium.allTimeTimes.title",
        tease: "stats.premium.allTimeTimes.tease",
    ) {
        TimesBreakdownView(title: "Classic best times", entries: PreviewData.times)
    }
    .padding()
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: false))
}

#Preview("Premium") {
    PremiumStatBlurOverlay(
        "stats.premium.allTimeTimes.title",
        tease: "stats.premium.allTimeTimes.tease",
    ) {
        TimesBreakdownView(title: "Classic best times", entries: PreviewData.times)
    }
    .padding()
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: true))
}

private enum PreviewData {
    static let times: [StatsOverview.DifficultyTimes] = [
        .init(difficulty: .easy, fastest: 245, average: 310),
        .init(difficulty: .medium, fastest: 512, average: 640),
        .init(difficulty: .hard, fastest: 901, average: 1180),
    ]
}
