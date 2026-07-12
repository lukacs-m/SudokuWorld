import Model
import SwiftUI

/// New game configuration: a sectioned catalog of variant cards, difficulty,
/// and hardcore mode. Which variants appear is `VariantCatalog`'s call.
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

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(VariantCatalog.sections, id: \.group) { section in
                        VariantSectionView(
                            group: section.group,
                            variants: section.variants,
                            selection: $variant,
                            theme: theme,
                        )
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
            .background(
                selected ? theme.accent.opacity(0.12) : theme.cellBackgroundAlternate.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 10),
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? theme.accent : theme.textPrimary)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// One catalog section: an uppercase header and a two-column grid of cards.
struct VariantSectionView: View {
    let group: SudokuVariantGroup
    let variants: [SudokuVariant]
    @Binding var selection: SudokuVariant
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: moduleString("section.\(group.slug)").localizedUppercase)
                .font(.footnote.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(theme.textSecondary)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10,
            ) {
                ForEach(variants, id: \.self) { candidate in
                    VariantCard(
                        variant: candidate,
                        selected: candidate == selection,
                        theme: theme,
                    ) {
                        selection = candidate
                    }
                }
            }
        }
    }
}
