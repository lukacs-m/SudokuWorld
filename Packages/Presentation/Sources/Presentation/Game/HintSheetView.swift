import Model
import SwiftUI

/// The hint explanation sheet: names the technique, explains the step, and
/// offers to apply it, reveal the selected cell instead, or open the
/// technique's lesson.
struct HintSheetView: View {
    let hint: Hint
    let variant: SudokuVariant
    let onApply: () -> Void
    let onReveal: () -> Void
    let onDismiss: () -> Void

    @State private var showLesson = false

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                    Text(verbatim: titleText)
                        .font(.headline)
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("common.close", bundle: .module))
                }

                Text(GameAccessibility.hintExplanation(hint, variant: variant))
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton("hint.apply", systemImage: "checkmark") {
                    onApply()
                }

                if case let .logical(technique) = hint.kind {
                    Button {
                        onReveal()
                    } label: {
                        Text("hint.revealInstead", bundle: .module)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)

                    Button {
                        showLesson = true
                    } label: {
                        Label {
                            Text("hint.learnMore", bundle: .module)
                        } icon: {
                            Image(systemName: "graduationcap")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .sheet(isPresented: $showLesson) {
                        LessonSheet(technique: technique)
                    }
                }
            }
            .padding(20)
        }
        .presentationDetents([.height(320), .medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var titleText: String {
        switch hint.kind {
        case let .logical(technique):
            moduleString("technique.\(technique.rawValue)")

        case .reveal:
            moduleString("hint.reveal.title")
        }
    }
}
