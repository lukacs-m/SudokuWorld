import SwiftUI

/// The home screen's entry into the learning section.
struct LearnCard: View {
    let onTap: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        Button {
            onTap()
        } label: {
            CardView {
                HStack(spacing: 14) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("home.learn", bundle: .module)
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Text("home.learn.subtitle", bundle: .module)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
