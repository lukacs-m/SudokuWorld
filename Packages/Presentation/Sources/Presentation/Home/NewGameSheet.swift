import Foundation
import Model
import SwiftUI

/// New game configuration as the mock's two-step flow: variant catalog first,
/// then difficulty (with personal bests) and hardcore mode. Each step pins
/// its call to action above the bottom edge so it never needs scrolling.
struct NewGameSheet: View {
    let hardcoreDefault: Bool
    let onStart: (SudokuVariant, Difficulty, GameMode) -> Void

    @State private var viewModel = NewGameViewModel()
    @State private var variant: SudokuVariant = .classic
    @State private var difficulty: Difficulty = .easy
    @State private var hardcore: Bool
    @State private var showDifficulty = false

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
            variantStep(theme: theme)
                .navigationDestination(isPresented: $showDifficulty) {
                    difficultyStep(theme: theme)
                }
        }
        .task { await viewModel.load() }
        #if os(iOS)
            .presentationCornerRadius(24)
        #endif
    }

    // MARK: - Step 1 · variant

    private func variantStep(theme: Theme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("home.newGame.subtitle", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                ForEach(VariantCatalog.sections, id: \.group) { section in
                    VariantSectionView(
                        group: section.group,
                        variants: section.variants,
                        selection: $variant,
                        theme: theme,
                    )
                }
            }
            .padding(20)
        }
        .background(theme.screenBackground)
        .safeAreaInset(edge: .bottom) {
            floatingBar(theme: theme) {
                PrimaryButton(
                    verbatim: String(
                        format: String(localized: "newGame.continueWith", bundle: .module),
                        moduleString("variant.\(variant.slug)"),
                    ),
                ) {
                    showDifficulty = true
                }
            }
        }
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

    // MARK: - Step 2 · difficulty

    private func difficultyStep(theme: Theme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("newGame.difficulty.subtitle", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                VStack(spacing: 8) {
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
            }
            .padding(20)
        }
        .background(theme.screenBackground)
        .safeAreaInset(edge: .bottom) {
            floatingBar(theme: theme) {
                PrimaryButton(
                    verbatim: String(
                        format: String(localized: "newGame.startWith", bundle: .module),
                        moduleString("difficulty.\(difficulty.slug)"),
                    ),
                    systemImage: "play.fill",
                ) {
                    dismiss()
                    onStart(variant, difficulty, hardcore ? .hardcore : .normal)
                }
            }
        }
        .navigationTitle(Text("newGame.difficulty", bundle: .module))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func difficultyRow(_ candidate: Difficulty, theme: Theme) -> some View {
        let selected = candidate == difficulty
        let best = viewModel.bestTime(variant: variant, difficulty: candidate)
        return Button {
            difficulty = candidate
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: moduleString("difficulty.\(candidate.slug)"))
                        .font(.headline.weight(selected ? .semibold : .regular))
                    if let best {
                        Text(
                            String(
                                format: String(localized: "newGame.bestTime", bundle: .module),
                                DurationFormatter.string(for: best),
                            ),
                        )
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                selected ? theme.accent.opacity(0.12) : theme.cardBackground,
                in: RoundedRectangle(cornerRadius: 14),
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? theme.accent : theme.textPrimary)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// Pins a call to action above the bottom edge; content scrolls beneath
    /// through a soft fade, so the button never has to be scrolled to.
    private func floatingBar(theme: Theme, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background {
                LinearGradient(
                    colors: [theme.screenBackground.opacity(0), theme.screenBackground],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .ignoresSafeArea()
            }
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
            SectionLabel(verbatim: moduleString("section.\(group.slug)"))
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
