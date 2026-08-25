import Model
import SwiftUI

/// How-to-play sheet for one variant: rules, a worked example, and tips.
/// Content lives in the string catalog under `rules.<slug>.*`.
struct VariantRulesView: View {
    let variant: SudokuVariant

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(theme: theme)
                    section(
                        "rules.section.howto",
                        text: moduleString("rules.\(variant.slug).howto"),
                        theme: theme,
                    )
                    section(
                        "rules.section.example",
                        text: moduleString("rules.\(variant.slug).example"),
                        theme: theme,
                    )
                    section(
                        "rules.section.tips",
                        text: moduleString("rules.\(variant.slug).tips"),
                        theme: theme,
                    )
                }
                .padding(20)
            }
            .background(theme.screenBackground)
            .navigationTitle(Text("rules.title", bundle: .module))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("common.close", bundle: .module)
                        }
                    }
                }
        }
        #if os(iOS)
        .presentationCornerRadius(24)
        #endif
    }

    private func header(theme: Theme) -> some View {
        HStack(spacing: 16) {
            VariantIconView(variant: variant, theme: theme)
                .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: moduleString("variant.\(variant.slug)"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Text(verbatim: moduleString("variant.\(variant.slug).subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func section(
        _ titleKey: LocalizedStringKey,
        text: String,
        theme: Theme,
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(titleKey)
                Text(verbatim: text)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
