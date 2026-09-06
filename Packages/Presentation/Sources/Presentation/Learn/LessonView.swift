import Model
import SwiftUI

/// One technique's lesson: definition, illustrated figure, where to look,
/// and a spotting tip. Pushed from the technique list; `LessonSheet` wraps
/// it for the hint sheet's "Learn more" link.
struct LessonView: View {
    let technique: Technique

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let figure = TechniqueFigure.figure(for: technique)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(theme: theme)
                section("learn.section.definition", part: "definition", theme: theme)
                figureCard(figure, theme: theme)
                section("learn.section.where", part: "where", theme: theme)
                section("learn.section.tip", part: "tip", theme: theme)
            }
            .padding(20)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text(verbatim: technique.lessonName))
        .toolbarTitleDisplayMode(.inline)
    }

    private func header(theme: Theme) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.accent)
                .frame(width: 64, height: 64)
                .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: technique.lessonName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Text(technique.lessonGroup.titleKey, bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func figureCard(_ figure: TechniqueFigure, theme: Theme) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("learn.section.example")
                LessonFigureView(figure: figure)
                Text(
                    figure.placement == nil
                        ? "learn.figure.legend.eliminations"
                        : "learn.figure.legend.placement",
                    bundle: .module,
                )
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func section(
        _ titleKey: LocalizedStringKey,
        part: String,
        theme: Theme,
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(titleKey)
                Text(verbatim: technique.lessonText(part))
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A lesson presented modally (from the hint sheet during a game).
struct LessonSheet: View {
    let technique: Technique

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LessonView(technique: technique)
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
}
