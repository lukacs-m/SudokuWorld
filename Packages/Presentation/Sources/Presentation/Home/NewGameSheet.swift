import Common
import Model
import SwiftUI

/// New game configuration: variant, difficulty, and hardcore mode. Samurai
/// only appears when its feature flag is on.
struct NewGameSheet: View {
    let hardcoreDefault: Bool
    let onStart: (SudokuVariant, Difficulty, GameMode) -> Void

    @State private var variant: SudokuVariant = .classic
    @State private var difficulty: Difficulty = .easy
    @State private var hardcore: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    init(
        hardcoreDefault: Bool,
        onStart: @escaping (SudokuVariant, Difficulty, GameMode) -> Void,
    ) {
        self.hardcoreDefault = hardcoreDefault
        self.onStart = onStart
        _hardcore = State(initialValue: hardcoreDefault)
    }

    private var variants: [SudokuVariant] {
        SudokuVariant.allCases.filter { $0 != .samurai || FeatureFlags.samuraiEnabled }
    }

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("newGame.variant", bundle: .module)
                        .font(.headline)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                        spacing: 10,
                    ) {
                        ForEach(variants, id: \.self) { candidate in
                            variantCell(candidate, theme: theme)
                        }
                    }

                    Text("newGame.difficulty", bundle: .module)
                        .font(.headline)
                    VStack(spacing: 6) {
                        ForEach(Difficulty.allCases, id: \.self) { candidate in
                            difficultyRow(candidate, theme: theme)
                        }
                    }

                    Toggle(isOn: $hardcore) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("newGame.hardcore", bundle: .module)
                                .font(.subheadline.weight(.medium))
                            Text("newGame.hardcore.detail", bundle: .module)
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .tint(theme.accent)

                    PrimaryButton("newGame.start", systemImage: "play.fill") {
                        dismiss()
                        onStart(variant, difficulty, hardcore ? .hardcore : .normal)
                    }
                }
                .padding(20)
            }
            .background(theme.screenBackground)
            .navigationTitle(Text("newGame.title", bundle: .module))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text("common.cancel", bundle: .module)
                        }
                    }
                }
        }
    }

    private func variantCell(_ candidate: SudokuVariant, theme: Theme) -> some View {
        let selected = candidate == variant
        return Button {
            variant = candidate
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon(for: candidate))
                    .font(.title3)
                Text(verbatim: moduleString("variant.\(candidate.slug)"))
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.white : theme.textPrimary)
        .background(
            selected ? theme.accent : theme.cellBackgroundAlternate.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 12),
        )
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func difficultyRow(_ candidate: Difficulty, theme: Theme) -> some View {
        let selected = candidate == difficulty
        return Button {
            difficulty = candidate
        } label: {
            HStack {
                Text(verbatim: moduleString("difficulty.\(candidate.slug)"))
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? theme.accent : theme.textPrimary)
        .background(
            selected ? theme.accent.opacity(0.12) : theme.cellBackgroundAlternate.opacity(0.4),
            in: RoundedRectangle(cornerRadius: 10),
        )
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func icon(for variant: SudokuVariant) -> String {
        switch variant {
        case .classic: "square.grid.3x3"
        case .mini6: "square.grid.2x2"
        case .killer: "sum"
        case .diagonal: "line.diagonal"
        case .windoku: "square.grid.3x3.middle.filled"
        case .evenOdd: "circle.square"
        case .samurai: "square.grid.3x3.fill.square"
        }
    }
}
