import DI
import Domain
import FactoryTesting
import Foundation
import Model
import Testing
@testable import Presentation

@Suite(.container)
@MainActor
struct GameViewModelTests {
    private func registerBaseMocks(
        startPuzzle: PuzzleDefinition = TestFixtures.puzzle(),
    ) -> (saves: SaveRecorder, completions: CompletionRecorder) {
        let saves = SaveRecorder()
        let completions = CompletionRecorder()
        Container.shared.startGameUseCase.register { MockStartGame(puzzle: startPuzzle) }
        Container.shared.resumeGameUseCase.register { MockResumeGame(saved: nil) }
        Container.shared.saveGameUseCase.register { MockSaveGame(recorder: saves) }
        Container.shared.abandonGameUseCase.register { MockAbandonGame() }
        Container.shared.completeGameUseCase.register { MockCompleteGame(recorder: completions) }
        Container.shared.getHintUseCase.register { MockGetHint() }
        Container.shared.revealCellUseCase.register { MockRevealCell() }
        Container.shared.settingsRepository.register { MockSettingsRepository() }
        return (saves, completions)
    }

    private func firstEmpty(_ session: GameSession) -> Int {
        (0..<session.board.count).first { session.board[$0].value == nil } ?? 0
    }

    @Test func startCreatesAPlayingSession() async {
        _ = registerBaseMocks()
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .normal,
        )))
        await viewModel.start()

        #expect(viewModel.phase == .playing)
        #expect(viewModel.session != nil)
        #expect(viewModel.topology?.cellCount == 81)
    }

    @Test func correctPlacementUpdatesBoardAndSchedulesAutosave() async throws {
        let (saves, _) = registerBaseMocks()
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .normal,
        )))
        await viewModel.start()

        guard let session = viewModel.session else {
            Issue.record("No session")
            return
        }
        let index = firstEmpty(session)
        viewModel.tapCell(index)
        viewModel.tapDigit(session.puzzle.solution[index])

        #expect(viewModel.session?.board[index].value == session.puzzle.solution[index])
        #expect(viewModel.feedback?.result == .placed)

        // The debounced autosave fires after ~500 ms.
        try await Task.sleep(for: .milliseconds(900))
        let count = await saves.snapshots.count
        #expect(count >= 1)
    }

    @Test func fogLiftCueFiresWhenTheNeverStuckRuleReveals() async {
        // Expert fog, seed 3: the opening has exactly one logical move, and
        // taking it leaves logic stuck, so the session lifts a window.
        // Generated off the main actor so the suite's timing-based tests
        // are not starved while this one builds its board.
        let puzzle = await PuzzleGenerator().generate(variant: .fogOfWar, difficulty: .expert, seed: 3)
        _ = registerBaseMocks(startPuzzle: puzzle)
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .fogOfWar,
            difficulty: .expert,
            mode: .normal,
        )))
        await viewModel.start()
        #expect(viewModel.fogLiftSequence == 0)

        guard let session = viewModel.session, let step = session.logicalFogPlacement() else {
            Issue.record("No logical fog move")
            return
        }
        let liftsBefore = session.fogAutoReveals
        viewModel.tapCell(step.cell)
        viewModel.tapDigit(step.digit)

        #expect(viewModel.session?.fogAutoReveals == liftsBefore + 1)
        #expect(viewModel.fogLiftSequence == 1)
        // The cue is for reveals the game made, not the player's own.
        #expect(viewModel.session?.isFogged(step.cell) == false)
    }

    @Test func noteModeTogglesNotes() async {
        _ = registerBaseMocks()
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .normal,
        )))
        await viewModel.start()

        guard let session = viewModel.session else {
            Issue.record("No session")
            return
        }
        let index = firstEmpty(session)
        viewModel.isNoteMode = true
        viewModel.tapCell(index)
        viewModel.tapDigit(5)

        #expect(viewModel.session?.board[index].value == nil)
        #expect(viewModel.session?.board[index].notes.contains(5) == true)
    }

    @Test func hardcoreLossCompletesAsLost() async throws {
        let (_, completions) = registerBaseMocks()
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .hardcore,
        )))
        await viewModel.start()

        guard let session = viewModel.session else {
            Issue.record("No session")
            return
        }
        let index = firstEmpty(session)
        let wrong = session.puzzle.solution[index] == 1 ? 2 : 1

        // Select once — tapping the same cell again would toggle it off.
        viewModel.tapCell(index)
        for _ in 0..<4 {
            viewModel.tapDigit(wrong)
            viewModel.eraseTapped()
        }
        // The finish flow runs in a Task; give it a beat.
        try await Task.sleep(for: .milliseconds(300))

        let outcomes = await completions.outcomes
        #expect(outcomes == [.lost])
        if case let .finished(summary) = viewModel.phase {
            #expect(summary.outcome == .lost)
        } else {
            Issue.record("Expected finished phase, got \(viewModel.phase)")
        }
    }

    @Test func solvingRunsCompletion() async throws {
        let (_, completions) = registerBaseMocks(
            startPuzzle: TestFixtures.almostSolvedPuzzle(),
        )
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .normal,
        )))
        await viewModel.start()

        guard let session = viewModel.session else {
            Issue.record("No session")
            return
        }
        let index = firstEmpty(session)
        viewModel.tapCell(index)
        viewModel.tapDigit(session.puzzle.solution[index])
        try await Task.sleep(for: .milliseconds(300))

        let outcomes = await completions.outcomes
        #expect(outcomes == [.won])
        if case let .finished(summary) = viewModel.phase {
            #expect(summary.outcome == .won)
        } else {
            Issue.record("Expected finished phase, got \(viewModel.phase)")
        }
    }

    @Test func hintsAreUnlimited() async {
        _ = registerBaseMocks()
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .normal,
        )))
        await viewModel.start()

        for _ in 0..<5 {
            #expect(viewModel.canRequestHint)
            await viewModel.requestHint()
            #expect(viewModel.presentedHint != nil)
            viewModel.applyPresentedHint()
        }
        #expect(viewModel.canRequestHint)
    }

    @Test func hardcoreModeDisallowsHints() async {
        _ = registerBaseMocks()
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .hardcore,
        )))
        await viewModel.start()
        #expect(!viewModel.canRequestHint)
    }

    @Test func pauseFreezesTheClock() async {
        _ = registerBaseMocks()
        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .normal,
        )))
        await viewModel.start()

        viewModel.pauseTapped()
        #expect(viewModel.phase == .paused)
        #expect(viewModel.session?.lastResume == nil)

        viewModel.resumeTapped()
        #expect(viewModel.phase == .playing)
        #expect(viewModel.session?.lastResume != nil)
    }

    @Test func digitFirstModeArmsDigits() async {
        Container.shared.settingsRepository.register {
            var settings = GameSettings.standard
            settings.inputMode = .digitFirst
            return MockSettingsRepository(settings: settings)
        }
        _ = registerBaseMocksKeepingSettings()

        let viewModel = GameViewModel(launch: GameLaunch(kind: .new(
            variant: .classic,
            difficulty: .easy,
            mode: .normal,
        )))
        await viewModel.start()

        guard let session = viewModel.session else {
            Issue.record("No session")
            return
        }
        let index = firstEmpty(session)
        let digit = session.puzzle.solution[index]

        viewModel.tapDigit(digit)
        #expect(viewModel.armedDigit == digit)
        viewModel.tapCell(index)
        #expect(viewModel.session?.board[index].value == digit)
    }

    /// Same as `registerBaseMocks` but leaves an existing settings
    /// registration untouched.
    private func registerBaseMocksKeepingSettings() -> (SaveRecorder, CompletionRecorder) {
        let saves = SaveRecorder()
        let completions = CompletionRecorder()
        Container.shared.startGameUseCase.register { MockStartGame() }
        Container.shared.resumeGameUseCase.register { MockResumeGame(saved: nil) }
        Container.shared.saveGameUseCase.register { MockSaveGame(recorder: saves) }
        Container.shared.abandonGameUseCase.register { MockAbandonGame() }
        Container.shared.completeGameUseCase.register { MockCompleteGame(recorder: completions) }
        Container.shared.getHintUseCase.register { MockGetHint() }
        Container.shared.revealCellUseCase.register { MockRevealCell() }
        return (saves, completions)
    }
}
