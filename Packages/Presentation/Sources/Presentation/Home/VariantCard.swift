import Model
import SwiftUI

/// One catalog card: illustrated tile top-left, optional badge top-right,
/// title, one-line subtitle. Selection tints the card with the theme
/// accent.
struct VariantCard: View {
    let variant: SudokuVariant
    let selected: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VariantIconView(variant: variant, theme: theme)
                        .frame(width: 52, height: 52)
                    Spacer(minLength: 0)
                    if let badge = VariantCatalog.badge(for: variant) {
                        VariantBadgeView(badge: badge, selected: selected, theme: theme)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: moduleString("variant.\(variant.slug)"))
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(verbatim: moduleString("variant.\(variant.slug).subtitle"))
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? theme.accent.opacity(0.14) : theme.cardBackground,
                in: RoundedRectangle(cornerRadius: 18),
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        selected ? theme.accent : theme.gridLine.opacity(0.35),
                        lineWidth: selected ? 1.5 : 1,
                    ),
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The POPULAR / NEW merchandising capsule.
struct VariantBadgeView: View {
    let badge: VariantCatalog.Badge
    let selected: Bool
    let theme: Theme

    /// Warm gold for NEW; deliberately theme-independent, like the mock.
    private static let gold = Color(red: 0.72, green: 0.58, blue: 0.24)

    var body: some View {
        Text(verbatim: moduleString(badge.titleKey).localizedUppercase)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch badge {
        case .popular: theme.accent.opacity(selected ? 0.22 : 0.14)
        case .new: Self.gold.opacity(0.16)
        }
    }

    private var foreground: Color {
        switch badge {
        case .popular: theme.accent
        case .new: Self.gold
        }
    }
}
