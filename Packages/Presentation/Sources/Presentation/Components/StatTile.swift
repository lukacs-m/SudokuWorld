public import SwiftUI

/// A compact labeled value used on the stats screen and completion card.
public struct StatTile: View {
    private let titleKey: LocalizedStringKey
    private let value: String

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    public init(_ titleKey: LocalizedStringKey, value: String) {
        self.titleKey = titleKey
        self.value = value
    }

    public var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
            Text(titleKey, bundle: .module)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            theme.cellBackgroundAlternate.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 10),
        )
    }
}
