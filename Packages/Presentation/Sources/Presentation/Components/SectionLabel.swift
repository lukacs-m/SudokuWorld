public import SwiftUI

/// The uppercase, letter-spaced label shown above card groups.
public struct SectionLabel: View {
    private let text: Text

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    public init(_ titleKey: LocalizedStringKey) {
        text = Text(titleKey, bundle: .module)
    }

    public init(verbatim value: String) {
        text = Text(verbatim: value)
    }

    public var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        text
            .textCase(.uppercase)
            .font(.footnote.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(theme.textSecondary)
    }
}
