import Domain
import Foundation
import Model
import SwiftUI

/// The soft wall: a free player asked for more of a variant than today's
/// lineup offers. Two equal options — wait for its next daily, or unlock
/// unlimited play. An invitation, never a lock screen.
struct SoftWallView: View {
    let variant: SudokuVariant
    let now: Date

    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    init(variant: SudokuVariant, now: Date = Date()) {
        self.variant = variant
        self.now = now
    }

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(spacing: 18) {
            VariantIconView(variant: variant, theme: theme)
                .frame(width: 64, height: 64)

            Text("softwall.title", bundle: .module)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 6) {
                if let next = nextAppearanceText {
                    Text(
                        String(
                            format: String(localized: "softwall.next", bundle: .module),
                            moduleString("variant.\(variant.slug)"),
                            next,
                        ),
                    )
                }
                Text(
                    String(
                        format: String(localized: "softwall.tomorrow", bundle: .module),
                        moduleString("variant.\(tomorrowVariants[0].slug)"),
                        moduleString("variant.\(tomorrowVariants[1].slug)"),
                    ),
                )
            }
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                option(
                    "softwall.wait",
                    systemImage: "calendar",
                    theme: theme,
                ) {
                    dismiss()
                }
                option(
                    "softwall.unlock",
                    systemImage: "infinity",
                    theme: theme,
                ) {
                    showPaywall = true
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.screenBackground)
        .presentationDetents([.medium])
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// Both choices carry the same visual weight — deliberately.
    private func option(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        theme: Theme,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(titleKey, bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.accent.opacity(0.4)),
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.accent)
    }

    private var nextAppearanceText: String? {
        guard let key = EventSeeds.nextAppearance(
            of: variant,
            after: EventSeeds.dailyDateKey(for: now),
        ), let date = EventSeeds.date(fromDateKey: key) else { return nil }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var tomorrowVariants: [SudokuVariant] {
        let tomorrowKey = EventSeeds.dailyDateKey(for: EventSeeds.nextDailyReset(after: now))
        return EventSeeds.dailySlots(dateKey: tomorrowKey).dropFirst().map(\.variant)
    }
}

/// Identifiable wrapper so call sites can drive `.sheet(item:)` with just a
/// variant.
struct SoftWallContext: Identifiable {
    let variant: SudokuVariant
    var id: String {
        variant.slug
    }
}
