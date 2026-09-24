import Model
import SwiftUI

/// The stats screen's doorway to the mastery matrix.
struct MasteryLinkCard: View {
    let overview: StatsOverview

    @Environment(StatsRouter.self) private var router
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        Button {
            router.push(.mastery(overview))
        } label: {
            CardView {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("stats.mastery", bundle: .module)
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Text("stats.mastery.subtitle", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
