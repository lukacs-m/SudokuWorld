public import SwiftUI

/// The standard rounded card container used across home, events, and stats.
public struct CardView<Content: View>: View {
    private let content: Content
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}
