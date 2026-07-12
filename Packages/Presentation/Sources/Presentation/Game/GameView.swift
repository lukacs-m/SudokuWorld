import Domain
import Foundation
import Model
import SwiftUI

/// The game screen: header (difficulty, clock, mistakes), board, digit pad,
/// and the pause / hint / completion / interstitial layers. Pushed from Home;
/// leaving mid-game saves silently, abandoning is always explicit.
struct GameView: View {
    @State private var viewModel: GameViewModel
    @State private var showExitDialog = false

    @Environment(Router.self) private var router
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: viewModel.sceneBecameActive()
            case .inactive, .background: viewModel.sceneLeftForeground()
            @unknown default: break
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
        .confirmationDialog(
            Text("game.exit.title", bundle: .module),
            isPresented: $showExitDialog,
            titleVisibility: .visible,
        ) {
            Button {
                viewModel.saveAndExit()
                router.pop()
            } label: {
                Text("game.exit.save", bundle: .module)
            }
            Button(role: .destructive) {
                Task {
                    await viewModel.abandon()
                    router.pop()
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
                    router.pop()
                } label: {
                    Text("game.finished.home", bundle: .module)
                }
            }

        case .playing, .paused, .finished:
            VStack(spacing: 12) {
                header(theme: theme)
                BoardView(viewModel: viewModel)
                    .padding(.horizontal, 8)
                    .opacity(viewModel.phase == .paused ? 0.05 : 1)
                Spacer(minLength: 0)
                DigitPadView(viewModel: viewModel)
                    .padding(.horizontal, 12)
                hintBar(theme: theme)
            }
            .padding(.vertical, 8)
        }
    }

    private func header(theme: Theme) -> some View {
        HStack {
            if let session = viewModel.session {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: moduleString("variant.\(session.puzzle.variant.slug)"))
                        .font(.headline)
                    Text(verbatim: moduleString(
                        "difficulty.\(session.puzzle.requestedDifficulty.slug)",
                    ))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                if let limit = session.mode.maxMistakes {
                    Label {
                        Text("\(session.mistakes)/\(limit)")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "heart.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(session.mistakes > 0 ? theme.conflict : theme.textSecondary)
                    .accessibilityLabel(String(
                        format: String(localized: "a11y.mistakes", bundle: .module),
                        session.mistakes,
                        limit,
                    ))
                } else if session.mistakes > 0 {
                    Label {
                        Text("\(session.mistakes)")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "xmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                }

                if viewModel.settings.timerVisible {
                    timerLabel(theme: theme, session: session)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func timerLabel(theme: Theme, session: GameSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(DurationFormatter.string(for: session.elapsed(at: context.date)))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(theme.textSecondary)
        }
    }

    @ViewBuilder
    private func hintBar(theme: Theme) -> some View {
        if let session = viewModel.session, session.mode.allowsHints {
            Button {
                Task { await viewModel.requestHint() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                    Text("game.hint.button", bundle: .module)
                    if let remaining = viewModel.hintsRemaining {
                        Text("(\(remaining))")
                            .monospacedDigit()
                    }
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.cellBackgroundAlternate.opacity(0.6), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.canRequestHint ? theme.accent : theme.textSecondary
                .opacity(0.5))
            .disabled(!viewModel.canRequestHint)
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
                    router.pop()
                },
                onAbandon: {
                    Task {
                        await viewModel.abandon()
                        router.pop()
                    }
                },
            )
        }

        if case let .finished(summary) = viewModel.phase {
            if let creative = viewModel.interstitial {
                InterstitialOverlayView(creative: creative) {
                    viewModel.dismissInterstitial()
                }
            } else {
                if summary.outcome == .won {
                    ConfettiView()
                        .ignoresSafeArea()
                }
                CompletionView(
                    summary: summary,
                    onNewGame: {
                        let launch = newGameLaunch()
                        router.pop()
                        router.push(.game(launch))
                    },
                    onHome: { router.popToRoot() },
                )
            }
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
                    router.pop()
                } else {
                    showExitDialog = true
                }
            } label: {
                Image(systemName: "chevron.backward")
            }
            .accessibilityLabel(Text("common.back", bundle: .module))
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
