import Common
import Domain
import Foundation
import Model
import SwiftUI

/// New game configuration as the mock's two-step flow: variant catalog first,
/// then difficulty (with personal bests) and hardcore mode. Each step pins
/// its call to action above the bottom edge so it never needs scrolling.
///
/// Free players get classic without limits; other variants route to today's
/// daily slot when the rotation offers them, and to the soft wall otherwise.
/// The full catalog stays browsable (cards, rules) for everyone.
struct NewGameSheet: View {
    let hardcoreDefault: Bool
    let isPremium: Bool
    let lineup: DailyLineup?
    let onStart: (SudokuVariant, Difficulty, GameMode) -> Void
    let onPlayDaily: (DailyLineup.Slot) -> Void
    let onSoftWall: (SudokuVariant) -> Void

    @State private var viewModel = NewGameViewModel()
    @State private var variant: SudokuVariant = .classic
    @State private var difficulty: Difficulty = .easy
    @State private var hardcore: Bool
    @State private var showDifficulty = false
    @State private var showRules = false
    /// Free-tier scheduling chips ("Play today" / "Daily Fri") per variant.
    @State private var chips: [SudokuVariant: String] = [:]

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    init(
        hardcoreDefault: Bool,
        isPremium: Bool,
        lineup: DailyLineup?,
        onStart: @escaping (SudokuVariant, Difficulty, GameMode) -> Void,
        onPlayDaily: @escaping (DailyLineup.Slot) -> Void,
        onSoftWall: @escaping (SudokuVariant) -> Void,
    ) {
        self.hardcoreDefault = hardcoreDefault
        self.isPremium = isPremium
        self.lineup = lineup
        self.onStart = onStart
        self.onPlayDaily = onPlayDaily
        self.onSoftWall = onSoftWall
        _hardcore = State(initialValue: hardcoreDefault)
    }

    private enum Access {
        case full
        case playToday(DailyLineup.Slot)
        case softWall
    }

    private var access: Access {
        if isPremium || variant == .classic {
            return .full
        }
        if let slot = lineup?.slots.first(where: { $0.variant == variant }),
           !slot.isCompleted
        {
            return .playToday(slot)
        }
        return .softWall
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
        .onAppear { computeChips() }
        .onAppear {
            #if DEBUG
                if let slug = LaunchHooks.rulesVariant,
                   let hooked = SudokuVariant(rawValue: slug)
                {
                    variant = hooked
                    showRules = true
                }
            #endif
        }
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
                        chips: chips,
                        theme: theme,
                    )
                }
            }
            .padding(20)
        }
        .background(theme.screenBackground)
        .safeAreaInset(edge: .bottom) {
            floatingBar(theme: theme) {
                startAction
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showRules = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(Text("rules.title", bundle: .module))
                }
            }
            .sheet(isPresented: $showRules) {
                VariantRulesView(variant: variant)
            }
    }

    /// Step 1's call to action, keyed off the free-tier access decision.
    @ViewBuilder
    private var startAction: some View {
        switch access {
        case .full:
            PrimaryButton(
                verbatim: String(
                    format: String(localized: "newGame.continueWith", bundle: .module),
                    moduleString("variant.\(variant.slug)"),
                ),
            ) {
                showDifficulty = true
            }

        case let .playToday(slot):
            PrimaryButton(
                verbatim: String(
                    format: String(localized: "newGame.playToday", bundle: .module),
                    moduleString("variant.\(variant.slug)"),
                ),
                systemImage: "play.fill",
            ) {
                dismiss()
                onPlayDaily(slot)
            }

        case .softWall:
            PrimaryButton(
                verbatim: String(
                    format: String(localized: "newGame.continueWith", bundle: .module),
                    moduleString("variant.\(variant.slug)"),
                ),
            ) {
                dismiss()
                onSoftWall(variant)
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

    /// One pass over the catalog when the sheet opens; `nextAppearance`
    /// scans forward per variant, cheap but not free — not body work.
    private func computeChips() {
        guard !isPremium, chips.isEmpty else { return }
        let todayKey = lineup?.dateKey ?? EventSeeds.dailyDateKey(for: Date())
        var result: [SudokuVariant: String] = [:]
        for candidate in VariantCatalog.available where candidate != .classic {
            if let slot = lineup?.slots.first(where: { $0.variant == candidate }),
               !slot.isCompleted
            {
                result[candidate] = String(localized: "catalog.playToday", bundle: .module)
            } else if let key = EventSeeds.nextAppearance(of: candidate, after: todayKey),
                      let date = EventSeeds.date(fromDateKey: key)
            {
                let withinAWeek = date.timeIntervalSinceNow < 7 * 86400
                result[candidate] = String(
                    format: String(localized: "catalog.dailyOn", bundle: .module),
                    withinAWeek
                        ? date.formatted(.dateTime.weekday(.abbreviated))
                        : date.formatted(.dateTime.month(.abbreviated).day()),
                )
            }
        }
        chips = result
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
    var chips: [SudokuVariant: String] = [:]
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
                        availabilityText: chips[candidate],
                        theme: theme,
                    ) {
                        selection = candidate
                    }
                }
            }
        }
    }
}
