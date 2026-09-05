import Common
import Domain
import Foundation
import Model
import StoreKit
import SwiftUI

/// The game screen: header (difficulty, clock, mistakes), board, digit pad,
/// and the pause / hint / completion layers. Pushed from Home; leaving
/// mid-game saves silently, abandoning is always explicit.
struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var showExitDialog = false
    @State private var softWall: SoftWallContext?
    @State private var showsFogLiftCue = false
    @State private var fogLiftCueTask: Task<Void, Never>?

    @Environment(Router.self) private var router
    @Environment(ThemeStore.self) private var themeStore
    @Environment(PremiumGate.self) private var premiumGate
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    init(launch: GameLaunch) {
        _viewModel = State(initialValue: GameViewModel(launch: launch))
    }

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        ZStack {
            theme.screenBackground.ignoresSafeArea()
            content(theme: theme)
            overlays(theme: theme)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent(theme: theme) }
        .task {
            await viewModel.start()
            if let cell = LaunchHooks.selectCell {
                viewModel.tapCell(cell)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: viewModel.sceneBecameActive()
            case .inactive, .background: viewModel.sceneLeftForeground()
            @unknown default: break
            }
        }
        .onChange(of: viewModel.fogLiftSequence) { _, _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showsFogLiftCue = true
            }
            AccessibilityNotification
                .Announcement(String(localized: "game.fogLifts", bundle: .module))
                .post()
            fogLiftCueTask?.cancel()
            fogLiftCueTask = Task {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.4)) {
                    showsFogLiftCue = false
                }
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            guard case let .finished(summary) = newPhase, summary.outcome == .won else { return }
            Task {
                // Let the confetti and completion card land before the
                // system decides whether to show the rating prompt.
                try? await Task.sleep(for: .seconds(2))
                requestReview()
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.presentedHint != nil },
                set: {
                    if !$0 {
                        viewModel.dismissHint()
                    }
                },
            ),
        ) {
            if let hint = viewModel.presentedHint {
                HintSheetView(
                    hint: hint,
                    variant: viewModel.session?.puzzle.variant ?? .classic,
                    onApply: { viewModel.applyPresentedHint() },
                    onReveal: { Task { await viewModel.requestReveal() } },
                    onDismiss: { viewModel.dismissHint() },
                )
            }
        }
        .sheet(item: $softWall) { context in
            SoftWallView(variant: context.variant)
        }
        .confirmationDialog(
            Text("game.exit.title", bundle: .module),
            isPresented: $showExitDialog,
            titleVisibility: .visible,
        ) {
            Button {
                viewModel.saveAndExit()
                router.dismissGame()
            } label: {
                Text("game.exit.save", bundle: .module)
            }
            Button(role: .destructive) {
                Task {
                    await viewModel.abandon()
                    router.dismissGame()
                }
            } label: {
                Text("game.exit.abandon", bundle: .module)
            }
            Button(role: .cancel) {} label: {
                Text("common.cancel", bundle: .module)
            }
        }
        .sensoryFeedback(trigger: viewModel.feedback) { _, newValue in
            guard viewModel.settings.hapticsEnabled, let newValue else { return nil }
            return switch newValue.result {
            case .placed: .impact(weight: .light)
            case .mistake: .warning
            case .solved: .success
            case .hardcoreLoss: .error
            case .rejected: nil
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(theme: Theme) -> some View {
        switch viewModel.phase {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("game.loading", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

        case .failed:
            ContentUnavailableView {
                Label {
                    Text("game.failed.title", bundle: .module)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                Text("game.failed.message", bundle: .module)
            } actions: {
                Button {
                    router.dismissGame()
                } label: {
                    Text("game.finished.home", bundle: .module)
                }
            }

        case .playing, .paused, .finished:
            VStack(spacing: 12) {
                header(theme: theme)
                board
                    .padding(.horizontal, 8)
                    .opacity(viewModel.phase == .paused ? 0.05 : 1)
                if viewModel.usesFairFog {
                    // Always laid out so the board never shifts when it
                    // appears — but only where a lift can happen.
                    FogLiftCueView(theme: theme)
                        .opacity(showsFogLiftCue ? 1 : 0)
                        .accessibilityHidden(!showsFogLiftCue)
                }
                Spacer(minLength: 0)
                DigitPadView(viewModel: viewModel)
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
        }
    }

    /// The cube is the one variant with its own rendering and gestures;
    /// every other shape goes through the flat canvas board.
    @ViewBuilder
    private var board: some View {
        if viewModel.session?.puzzle.variant == .cube {
            CubeBoardView(viewModel: viewModel)
        } else {
            BoardView(viewModel: viewModel)
        }
    }

    /// The mock's Time / Mistakes / Hints tile row.
    @ViewBuilder
    private func header(theme: Theme) -> some View {
        if let session = viewModel.session {
            HStack(spacing: 10) {
                if viewModel.settings.timerVisible {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        StatTile(
                            "game.finished.time",
                            value: DurationFormatter.string(for: session.elapsed(at: context.date)),
                        )
                    }
                }
                if let limit = session.mode.maxMistakes {
                    StatTile(
                        "game.finished.mistakes",
                        value: "\(session.mistakes)/\(limit)",
                        valueColor: session.mistakes > 0 ? theme.conflict : nil,
                    )
                } else {
                    StatTile("game.finished.mistakes", value: "\(session.mistakes)")
                }
                if session.mode.allowsHints {
                    StatTile("game.finished.hints", value: "\(session.hintsUsed)")
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func overlays(theme _: Theme) -> some View {
        if viewModel.phase == .paused, let session = viewModel.session {
            PauseOverlayView(
                elapsedText: DurationFormatter.string(for: session.elapsed(at: Date())),
                onResume: { viewModel.resumeTapped() },
                onSaveAndExit: {
                    viewModel.saveAndExit()
                    router.dismissGame()
                },
                onAbandon: {
                    Task {
                        await viewModel.abandon()
                        router.dismissGame()
                    }
                },
            )
        }

        if case let .finished(summary) = viewModel.phase {
            if summary.outcome == .won {
                ConfettiView()
                    .ignoresSafeArea()
            }
            CompletionView(
                summary: summary,
                onNewGame: {
                    // A free player finishing a variant daily gets the soft
                    // wall (next rotation vs. unlock), never a fresh board.
                    if !premiumGate.isPremium,
                       let dailyVariant = viewModel.session?.context.dailyVariant,
                       dailyVariant != .classic
                    {
                        softWall = SoftWallContext(variant: dailyVariant)
                    } else {
                        // Fresh presentation token, so the cover rebuilds
                        // even for an identical configuration.
                        router.play(newGameLaunch())
                    }
                },
                onHome: { router.goHome() },
            )
        }
    }

    private func newGameLaunch() -> GameLaunch {
        guard let session = viewModel.session else {
            return GameLaunch(kind: .new(variant: .classic, difficulty: .easy, mode: .normal))
        }
        return GameLaunch(kind: .new(
            variant: session.puzzle.variant,
            difficulty: session.puzzle.requestedDifficulty,
            mode: session.mode,
        ))
    }

    @ToolbarContentBuilder
    private func toolbarContent(theme _: Theme) -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                if case .finished = viewModel.phase {
                    router.dismissGame()
                } else {
                    showExitDialog = true
                }
            } label: {
                Image(systemName: "chevron.backward")
            }
            .accessibilityLabel(Text("common.back", bundle: .module))
        }
        ToolbarItem(placement: .principal) {
            if let session = viewModel.session {
                VStack(spacing: 0) {
                    Text(verbatim: moduleString("variant.\(session.puzzle.variant.slug)"))
                        .font(.headline)
                    Text(verbatim: moduleString(
                        "difficulty.\(session.puzzle.requestedDifficulty.slug)",
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if viewModel.phase == .playing {
                Button {
                    viewModel.pauseTapped()
                } label: {
                    Image(systemName: "pause.circle")
                }
                .accessibilityLabel(Text("game.paused.title", bundle: .module))
            }
        }
    }
}
