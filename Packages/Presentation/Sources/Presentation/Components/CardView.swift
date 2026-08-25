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
            .padding(18)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .shadow(
                color: Color(red: 0.157, green: 0.141, blue: 0.110).opacity(0.05),
                radius: 16,
                y: 4,
            )
    }
}
