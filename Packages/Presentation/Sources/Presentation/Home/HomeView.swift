import Common
import Foundation
import Model
import SwiftUI

/// The home screen: continue, new game, daily challenge, and entries into
/// events, stats, and settings.
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showNewGame = false
    @State private var showPaywall = false
    @State private var hardcoreDefault = false
    @State private var launchHooksHandled = false

    @Environment(Router.self) private var router
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        ScrollView {
            VStack(spacing: 16) {
                header(theme: theme)

                if let content = viewModel.state.value {
                    if let saved = content.continueGame {
                        ContinueGameCard(saved: saved) {
                            router.push(.game(GameLaunch(kind: .resume)))
                        }
                    }
                    PrimaryButton("home.newGame", systemImage: "plus") {
                        showNewGame = true
                    }
                    DailyChallengeCard(
                        dailyState: viewModel.dailyState,
                        dailyStreak: content.streaks.currentDailyStreak,
                    ) {
                        router.push(.game(GameLaunch(kind: .daily)))
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                }

                navigationRow(theme: theme)

                if !viewModel.isPremium, let banner = viewModel.banner {
                    BannerAdView(creative: banner) {
                        showPaywall = true
                    }
                }
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text("app.title", bundle: .module))
        .task { await viewModel.refresh() }
        .onAppear {
            // Refresh when returning from a game (task only fires once).
            Task { await viewModel.refresh() }
            handleLaunchHooks()
        }
        .sheet(isPresented: $showNewGame) {
            NewGameSheet(hardcoreDefault: hardcoreDefault) { variant, difficulty, mode in
                router.push(.game(GameLaunch(
                    kind: .new(variant: variant, difficulty: difficulty, mode: mode),
                )))
            }
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
            if let start = LaunchHooks.autostart,
               let variant = SudokuVariant(rawValue: start.variantSlug),
               let difficulty = Difficulty(rawValue: start.difficultySlug) {
                router.push(.game(GameLaunch(
                    kind: .new(variant: variant, difficulty: difficulty, mode: .normal),
                )))
            }
        #endif
    }

    private func header(theme: Theme) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("home.welcome", bundle: .module)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
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
            if !viewModel.isPremium {
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

    private func navigationRow(theme: Theme) -> some View {
        HStack(spacing: 10) {
            navigationTile("home.events", systemImage: "trophy", theme: theme) {
                router.push(.events)
            }
            navigationTile("home.stats", systemImage: "chart.bar", theme: theme) {
                router.push(.stats)
            }
            navigationTile("home.settings", systemImage: "gearshape", theme: theme) {
                router.push(.settings)
            }
            #if DEBUG
                navigationTile("home.debug", systemImage: "hammer", theme: theme) {
                    router.push(.debug)
                }
            #endif
        }
    }

    private func navigationTile(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        theme: Theme,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                Text(titleKey, bundle: .module)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
