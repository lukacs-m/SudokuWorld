import Domain
import Foundation
import Model
import SwiftUI

/// Digit entry pad plus the tool row (undo, erase, notes, redo). Digits show
/// how many placements remain and dim when exhausted; in digit-first mode
/// the armed digit renders highlighted.
struct DigitPadView: View {
    let viewModel: GameViewModel

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let size = viewModel.topology?.size ?? 9

        VStack(spacing: 12) {
            toolRow(theme: theme)
            digitRow(size: size, theme: theme)
        }
    }

    private func toolRow(theme: Theme) -> some View {
        HStack(spacing: 12) {
            toolButton(
                "game.tool.undo",
                systemImage: "arrow.uturn.backward",
                enabled: viewModel.session?.canUndo ?? false,
                theme: theme,
            ) {
                viewModel.undoTapped()
            }
            toolButton(
                "game.tool.erase",
                systemImage: "eraser",
                enabled: viewModel.selectedCell != nil,
                theme: theme,
            ) {
                viewModel.eraseTapped()
            }
            noteToggle(theme: theme)
            toolButton(
                "game.tool.redo",
                systemImage: "arrow.uturn.forward",
                enabled: viewModel.session?.canRedo ?? false,
                theme: theme,
            ) {
                viewModel.redoTapped()
            }
        }
    }

    private func noteToggle(theme: Theme) -> some View {
        Button {
            viewModel.isNoteMode.toggle()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "pencil")
                    .font(.body.weight(.medium))
                Text("game.tool.notes", bundle: .module)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.isNoteMode ? Color.white : theme.textSecondary)
        .background(
            viewModel.isNoteMode ? theme.accent : theme.cellBackgroundAlternate.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 10),
        )
        .accessibilityLabel(Text("game.tool.notes", bundle: .module))
        .accessibilityAddTraits(viewModel.isNoteMode ? [.isButton, .isSelected] : .isButton)
    }

    private func toolButton(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        enabled: Bool,
        theme: Theme,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                Text(titleKey, bundle: .module)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? theme.textPrimary : theme.textSecondary.opacity(0.4))
        .background(
            theme.cellBackgroundAlternate.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 10),
        )
        .disabled(!enabled)
    }

    private func digitRow(size: Int, theme: Theme) -> some View {
        HStack(spacing: 6) {
            ForEach(1 ... size, id: \.self) { digit in
                digitButton(digit, theme: theme)
            }
        }
    }

    private func digitButton(_ digit: Int, theme: Theme) -> some View {
        let remaining = viewModel.remainingCount(for: digit)
        let isArmed = viewModel.armedDigit == digit
        return Button {
            viewModel.tapDigit(digit)
        } label: {
            VStack(spacing: 1) {
                Text("\(digit)")
                    .font(.system(.title2, design: .rounded).weight(.medium))
                Text("\(remaining)")
                    .font(.caption2)
                    .opacity(remaining > 0 ? 0.7 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isArmed ? Color.white : theme.playerText)
        .background(
            isArmed ? theme.accent : theme.cellBackgroundAlternate.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 10),
        )
        .opacity(remaining == 0 && !isArmed ? 0.35 : 1)
        .accessibilityLabel(String(
            format: String(localized: "a11y.digit.button", bundle: .module),
            digit,
            remaining,
        ))
    }
}
