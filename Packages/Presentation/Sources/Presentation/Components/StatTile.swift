public import SwiftUI

/// A compact labeled value used on the stats screen and completion card.
public struct StatTile: View {
    private let titleKey: LocalizedStringKey
    private let value: String
    private let valueColor: Color?

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    public init(_ titleKey: LocalizedStringKey, value: String, valueColor: Color? = nil) {
        self.titleKey = titleKey
        self.value = value
        self.valueColor = valueColor
    }

    public var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? theme.textPrimary)
            Text(titleKey, bundle: .module)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            theme.cellBackgroundAlternate.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 12),
        )
    }
}
