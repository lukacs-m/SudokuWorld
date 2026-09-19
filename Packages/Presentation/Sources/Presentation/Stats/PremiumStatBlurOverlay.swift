import Model
import SwiftUI

/// Wraps premium-only stat card content for free players: the real content
/// stays underneath, blurred and washed out, with a lock, the stat's name and a
/// one-line tease on top. The whole card opens the paywall. Premium players get
/// the content untouched. The card itself is supplied here, so the locked state
/// keeps the standard card background, shadow and elevation.
struct PremiumStatBlurOverlay<Content: View>: View {
    private let titleKey: LocalizedStringKey
    private let teaseKey: LocalizedStringKey
    private let labelAlignment: Alignment
    private let content: Content

    @State private var showPaywall = false
    @Environment(PremiumGate.self) private var premiumGate
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    /// `labelAlignment` puts the lock label at the top of content taller than
    /// a screen (the mastery matrix), where a centred label would only show
    /// up mid-scroll.
    init(
        _ titleKey: LocalizedStringKey,
        tease teaseKey: LocalizedStringKey,
        labelAlignment: Alignment = .center,
        @ViewBuilder content: () -> Content,
    ) {
        self.titleKey = titleKey
        self.teaseKey = teaseKey
        self.labelAlignment = labelAlignment
        self.content = content()
    }

    var body: some View {
        Group {
            if premiumGate.isPremium {
                CardView { content }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    locked(theme: themeStore.theme(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// The label is a `ZStack` sibling rather than an overlay so that it grows
    /// the card at accessibility text sizes instead of spilling over the
    /// neighbouring ones. The clip keeps the blur's bleed off the card's edge.
    private func locked(theme: Theme) -> some View {
        CardView {
            ZStack(alignment: labelAlignment) {
                content.premiumStatBlur(theme: theme)
                LockedStatLabel(titleKey: titleKey, teaseKey: teaseKey, theme: theme)
                    .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// How a locked preview hides the player's real numbers, wherever it covers
/// them: the radius scales with the text it sits on, so raising Dynamic Type
/// cannot bring the values back, and the wash keeps the lock label legible.
/// Hidden from VoiceOver, which the lock label speaks for. Callers clip the
/// region the bleed may not leave.
private struct PremiumStatBlur: ViewModifier {
    let theme: Theme

    @ScaledMetric(relativeTo: .body) private var radius: CGFloat = 5

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .overlay(theme.screenBackground.opacity(0.25))
            .accessibilityHidden(true)
    }
}

extension View {
    func premiumStatBlur(theme: Theme) -> some View {
        modifier(PremiumStatBlur(theme: theme))
    }
}

/// Cards that blur only part of their content place this themselves, so the
/// padding belongs to the caller.
struct LockedStatLabel: View {
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
    }
}

#Preview("Free") {
    PremiumStatBlurOverlay(
        "stats.premium.allTimeTimes.title",
        tease: "stats.premium.allTimeTimes.tease",
    ) {
        TimesBreakdownContent(title: "Classic best times", entries: PreviewData.times)
    }
    .padding()
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: false))
}

/// The tightest case for the locked label: one row of content, largest text.
#Preview("Free · one row · AX5") {
    PremiumStatBlurOverlay(
        "stats.premium.allTimeTimes.title",
        tease: "stats.premium.allTimeTimes.tease",
    ) {
        TimesBreakdownContent(
            title: "Classic best times",
            entries: Array(PreviewData.times.prefix(1)),
        )
    }
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: false))
}

#Preview("Premium") {
    PremiumStatBlurOverlay(
        "stats.premium.allTimeTimes.title",
        tease: "stats.premium.allTimeTimes.tease",
    ) {
        TimesBreakdownContent(title: "Classic best times", entries: PreviewData.times)
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
