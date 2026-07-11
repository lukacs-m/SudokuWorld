import Model
import SwiftUI

/// The hint explanation sheet: names the technique, explains the step, and
/// offers to apply it (or reveal the selected cell instead).
struct HintSheetView: View {
    let hint: Hint
    let onApply: () -> Void
    let onReveal: () -> Void
    let onDismiss: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(theme.accent)
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

            Text(GameAccessibility.hintExplanation(hint))
                .font(.body)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton("hint.apply", systemImage: "checkmark") {
                onApply()
            }

            if case .logical = hint.kind {
                Button {
                    onReveal()
                } label: {
                    Text("hint.revealInstead", bundle: .module)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(20)
        .presentationDetents([.height(280)])
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
