import Common
import Foundation
import Model
import SwiftUI

/// The home screen: continue, new game, daily challenge, the learning
/// section, and entries into events, stats, and settings.
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showNewGame = false
    @State private var showPaywall = false
    @State private var softWall: SoftWallContext?
    @State private var hardcoreDefault = false
    @State private var launchHooksHandled = false
    @State private var showLearn = false

    #if DEBUG
        @State private var hookLesson: Technique?
    #endif

    @Environment(Router.self) private var router
    @Environment(ThemeStore.self) private var themeStore
    @Environment(PremiumGate.self) private var premiumGate
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        ScrollView {
            VStack(spacing: 20) {
                header(theme: theme)

                if let content = viewModel.state.value {
                    if let saved = content.continueGame {
                        ContinueGameCard(saved: saved) {
                            router.play(GameLaunch(kind: .resume))
                        }
                    }
                    if content.continueGame != nil {
                        newGameRow(theme: theme)
                    } else {
                        PrimaryButton("home.newGame", systemImage: "plus") {
                            showNewGame = true
                        }
                    }
                    DailyChallengeCard(
                        dailyState: viewModel.dailyState,
                        dailyStreak: content.streaks.currentDailyStreak,
                    ) { slot in
                        guard let lineup = viewModel.dailyState.value else { return }
                        router.play(GameLaunch(kind: .daily(
                            dateKey: lineup.dateKey,
                            variant: slot.variant,
                            difficulty: slot.difficulty,
                        )))
                    }
                    LearnCard { showLearn = true }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                }
            }
            .padding(20)
        }
        .background(theme.screenBackground)
        .navigationDestination(isPresented: $showLearn) {
            LearnView()
        }
        #if DEBUG
        .navigationDestination(item: $hookLesson) { technique in
            LessonView(technique: technique)
        }
        #endif
        .navigationTitle(Text("app.title", bundle: .module))
        .toolbarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
        .onAppear {
            // Refresh when the tab is re-selected (task only fires once).
            Task { await viewModel.refresh() }
            handleLaunchHooks()
        }
        .onChange(of: router.game) { _, game in
            // The game cover doesn't refire onAppear underneath on dismissal.
            if game == nil {
                Task { await viewModel.refresh() }
            }
        }
        .sheet(isPresented: $showNewGame) {
            NewGameSheet(
                hardcoreDefault: hardcoreDefault,
                isPremium: premiumGate.isPremium,
                lineup: viewModel.dailyState.value,
                onStart: { variant, difficulty, mode in
                    router.play(GameLaunch(
                        kind: .new(variant: variant, difficulty: difficulty, mode: mode),
                    ))
                },
                onPlayDaily: { slot in
                    guard let lineup = viewModel.dailyState.value else { return }
                    router.play(GameLaunch(kind: .daily(
                        dateKey: lineup.dateKey,
                        variant: slot.variant,
                        difficulty: slot.difficulty,
                    )))
                },
                onSoftWall: { variant in
                    softWall = SoftWallContext(variant: variant)
                },
            )
        }
        .sheet(item: $softWall) { context in
            SoftWallView(variant: context.variant)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// DEBUG-only automation entry points; no-ops in release builds.
    private func handleLaunchHooks() {
        #if DEBUG
            guard !launchHooksHandled else {
                return
            }
            launchHooksHandled = true
            if LaunchHooks.openNewGameSheet {
                showNewGame = true
            }
            if LaunchHooks.openPaywall {
                showPaywall = true
            }
            if LaunchHooks.openLearn {
                showLearn = true
            }
            if let slug = LaunchHooks.lessonTechnique {
                hookLesson = Technique(rawValue: slug)
            }
            if let start = LaunchHooks.autostart,
               let variant = SudokuVariant(rawValue: start.variantSlug),
               let difficulty = Difficulty(rawValue: start.difficultySlug)
            {
                router.play(GameLaunch(
                    kind: .new(variant: variant, difficulty: difficulty, mode: .normal),
                ))
            }
        #endif
    }

    /// The mock's "New game" entry card, used when a resumable game already
    /// owns the primary button.
    private func newGameRow(theme: Theme) -> some View {
        Button {
            showNewGame = true
        } label: {
            CardView {
                HStack(spacing: 14) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("home.newGame", bundle: .module)
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Text("home.newGame.subtitle", bundle: .module)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// The mock's greeting block: time-of-day line, invitation, date.
    private var greetingKey: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5 ..< 12: "home.greeting.morning"
        case 12 ..< 18: "home.greeting.afternoon"
        default: "home.greeting.evening"
        }
    }

    private func header(theme: Theme) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingKey, bundle: .module)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("home.greeting.subtitle", bundle: .module)
                    .font(.title3)
                    .foregroundStyle(theme.textSecondary)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 8)
                if let streaks = viewModel.state.value?.streaks, streaks.currentWinStreak > 1 {
                    Text(
                        String(
                            format: String(localized: "home.winStreak", bundle: .module),
                            streaks.currentWinStreak,
                        ),
                    )
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
            if !premiumGate.isPremium {
                Button {
                    showPaywall = true
                } label: {
                    Label {
                        Text("home.premium", bundle: .module)
                    } icon: {
                        Image(systemName: "crown.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.accent.opacity(0.12), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
        }
    }
}
