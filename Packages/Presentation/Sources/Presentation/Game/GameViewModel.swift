import Common
import DI
public import Domain
public import Foundation
public import Model
public import Observation

/// Owns the live `GameSession` and every interaction of the game screen:
/// input modes, notes, undo/redo, hints, autosave, the clock, and the
/// completion flow (record → achievements → leaderboards).
@MainActor
@Observable
public final class GameViewModel {
    public enum Phase: Equatable {
        case loading
        case playing
        case paused
        case finished(CompletionSummary)
        case failed
    }

    // MARK: - Observable state

    public private(set) var phase: Phase = .loading
    public private(set) var session: GameSession?
    public private(set) var selectedCell: Int?
    /// Armed digit in digit-first input mode.
    public private(set) var armedDigit: Int?
    public var isNoteMode = false
    public private(set) var conflicts: Set<Int> = []
    /// The hint currently presented in the hint sheet.
    public private(set) var presentedHint: Hint?
    public private(set) var settings: GameSettings = .standard
    /// Drives `.sensoryFeedback` in the view; bumped on every applied move.
    public private(set) var feedback: MoveFeedback?
    /// Bumped each time a move makes the fog lift on its own (fair fog's
    /// never-stuck rule); the view shows the "fog lifts" cue on change.
    public private(set) var fogLiftSequence = 0

    public struct MoveFeedback: Equatable {
        public let result: MoveResult
        /// Monotonic counter so identical consecutive results still trigger.
        public let sequence: Int
    }

    // MARK: - Dependencies

    @ObservationIgnored @Injected(\.startGameUseCase) private var startGame
    @ObservationIgnored @Injected(\.resumeGameUseCase) private var resumeGame
    @ObservationIgnored @Injected(\.saveGameUseCase) private var saveGame
    @ObservationIgnored @Injected(\.abandonGameUseCase) private var abandonGame
    @ObservationIgnored @Injected(\.completeGameUseCase) private var completeGame
    @ObservationIgnored @Injected(\.getHintUseCase) private var getHint
    @ObservationIgnored @Injected(\.revealCellUseCase) private var revealCell
    @ObservationIgnored @Injected(\.settingsRepository) private var settingsRepository

    private let launch: GameLaunch
    private var autosaveTask: Task<Void, Never>?
    private var feedbackSequence = 0
    private var knownFogAutoReveals = 0
    /// Peer lookup for selection highlighting, derived from the topology.
    private var peersByCell: [[Int]] = []

    public init(launch: GameLaunch) {
        self.launch = launch
    }

    // MARK: - Derived state

    /// Stored (not computed) because per-puzzle shapes (jigsaw) rebuild
    /// their lookup tables on every construction; set alongside `session`.
    public private(set) var topology: GridTopology?

    /// Only fair fog lifts a window on its own, so only it reserves the
    /// cue's slot under the board.
    public var usesFairFog: Bool {
        session?.usesFairFog ?? false
    }

    public var canRequestHint: Bool {
        guard let session else { return false }
        return session.mode.allowsHints && phase == .playing
    }

    /// Cells sharing a house or cage with the selection.
    public var relatedCells: Set<Int> {
        guard let selectedCell, peersByCell.indices.contains(selectedCell) else { return [] }
        return Set(peersByCell[selectedCell])
    }

    /// Cells holding the same digit as the selection (or the armed digit).
    public var sameDigitCells: Set<Int> {
        guard let session else { return [] }
        let digit: Int? = if let armedDigit {
            armedDigit
        } else if let selectedCell {
            session.board[selectedCell].value
        } else {
            nil
        }
        guard let digit else { return [] }
        return Set((0 ..< session.board.count).filter { session.board[$0].value == digit })
    }

    /// Remaining placements per digit (for the digit pad badges).
    public func remainingCount(for digit: Int) -> Int {
        guard let session else { return 0 }
        let total = session.puzzle.solution.count { $0 == digit }
        let placed = (0 ..< session.board.count).count { session.board[$0].value == digit }
        return max(0, total - placed)
    }

    // MARK: - Lifecycle

    public func start(now: Date = Date()) async {
        settings = await settingsRepository.gameSettings()

        guard var newSession = await restoreOrStartSession(now: now) else {
            phase = .failed
            return
        }
        newSession.resume(at: now)
        session = newSession
        topology = TopologyFactory.topology(for: newSession.puzzle)
        peersByCell = Self.buildPeers(for: newSession.puzzle)
        knownFogAutoReveals = newSession.fogAutoReveals
        conflicts = []
        phase = .playing
        #if DEBUG
            if LaunchHooks.fogAutoplayMoves > 0 {
                Task { await debugAutoplayFog(moves: LaunchHooks.fogAutoplayMoves) }
            }
        #endif
    }

    #if DEBUG
        /// Screenshot tooling: plays logic-only fog moves a beat after the
        /// board is on screen, so the "fog lifts" cue is photographable.
        private func debugAutoplayFog(moves: Int) async {
            try? await Task.sleep(for: .seconds(3))
            for _ in 0 ..< moves {
                guard let step = session?.logicalFogPlacement() else { return }
                apply(digit: step.digit, at: step.cell)
            }
        }
    #endif

    // MARK: - Input

    public func tapCell(_ index: Int) {
        guard phase == .playing, let session, !session.isOver else { return }
        // Fogged cells are not interactable until revealed.
        guard !session.isFogged(index) else { return }
        if let digit = armedDigit {
            apply(digit: digit, at: index)
            return
        }
        selectedCell = selectedCell == index ? nil : index
    }

    public func tapDigit(_ digit: Int, now: Date = Date()) {
        guard phase == .playing else { return }
        if settings.inputMode == .digitFirst, selectedCell == nil {
            armedDigit = armedDigit == digit ? nil : digit
            return
        }
        guard let cell = selectedCell else { return }
        apply(digit: digit, at: cell, now: now)
    }

    public func eraseTapped() {
        guard phase == .playing, var session, let cell = selectedCell else { return }
        let result = session.clear(at: cell)
        self.session = session
        afterMove(result)
    }

    public func undoTapped() {
        guard var session else { return }
        if session.undo() {
            self.session = session
            afterMove(.placed)
        }
    }

    public func redoTapped() {
        guard var session else { return }
        if session.redo() {
            self.session = session
            afterMove(.placed)
        }
    }

    private func apply(digit: Int, at index: Int, now: Date = Date()) {
        guard var session else { return }
        let result: MoveResult = if isNoteMode {
            session.toggleNote(digit, at: index)
        } else {
            session.place(digit, at: index, autoCleanNotes: settings.autoCleanNotes)
        }
        self.session = session
        afterMove(result, now: now)
    }

    private func afterMove(_ result: MoveResult, now: Date = Date()) {
        guard let session else { return }
        conflicts = session.conflicts()
        feedbackSequence += 1
        feedback = MoveFeedback(result: result, sequence: feedbackSequence)
        if session.fogAutoReveals > knownFogAutoReveals {
            knownFogAutoReveals = session.fogAutoReveals
            fogLiftSequence += 1
        }
        scheduleAutosave()

        switch result {
        case .solved:
            Task { await finish(outcome: .won, now: now) }

        case .hardcoreLoss:
            Task { await finish(outcome: .lost, now: now) }

        default:
            break
        }
    }

    // MARK: - Hints

    public func requestHint() async {
        guard canRequestHint, let session else { return }
        presentedHint = await getHint(board: session.board, puzzle: session.puzzle)
    }

    public func requestReveal() async {
        guard canRequestHint, let session else { return }
        presentedHint = await revealCell(
            board: session.board,
            puzzle: session.puzzle,
            preferredCell: selectedCell,
        )
    }

    public func applyPresentedHint(now: Date = Date()) {
        guard var session, let hint = presentedHint else { return }
        let result = session.applyHint(hint, autoCleanNotes: settings.autoCleanNotes)
        self.session = session
        presentedHint = nil
        afterMove(result, now: now)
    }

    public func dismissHint() {
        presentedHint = nil
    }

    // MARK: - Pause / scene lifecycle

    public func pauseTapped(now: Date = Date()) {
        guard phase == .playing, var session else { return }
        session.pause(at: now)
        self.session = session
        phase = .paused
        saveImmediately(now: now)
    }

    public func resumeTapped(now: Date = Date()) {
        guard phase == .paused, var session else { return }
        session.resume(at: now)
        self.session = session
        phase = .playing
    }

    /// Mirrors `scenePhase`: leaving the foreground pauses the clock and
    /// snapshots the game; returning resumes only if the player was playing.
    public func sceneBecameActive(now: Date = Date()) {
        guard phase == .playing, var session else { return }
        session.resume(at: now)
        self.session = session
    }

    public func sceneLeftForeground(now: Date = Date()) {
        guard var session, !session.isOver else { return }
        session.pause(at: now)
        self.session = session
        saveImmediately(now: now)
    }

    // MARK: - Exit

    /// Abandon from the pause menu or back confirmation. Records the game.
    public func abandon(now: Date = Date()) async {
        guard let session, !session.isOver else { return }
        autosaveTask?.cancel()
        await abandonGame(session: session, at: now)
    }

    /// Leave without abandoning (game stays saved for "Continue").
    public func saveAndExit(now: Date = Date()) {
        guard var session, !session.isOver else { return }
        session.pause(at: now)
        self.session = session
        autosaveTask?.cancel()
        let snapshot = session.savedGame(at: now)
        Task { [saveGame] in
            await saveGame(snapshot)
        }
    }

    // MARK: - Completion

    private func finish(outcome: GameOutcome, now: Date) async {
        guard var session else { return }
        autosaveTask?.cancel()
        session.pause(at: now)
        self.session = session

        let summary = await completeGame(session: session, outcome: outcome, at: now)
        phase = .finished(summary)
    }

    // MARK: - Autosave

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            guard let session, !session.isOver else { return }
            await saveGame(session.savedGame(at: Date()))
        }
    }

    private func saveImmediately(now: Date) {
        autosaveTask?.cancel()
        guard let session, !session.isOver else { return }
        let snapshot = session.savedGame(at: now)
        Task { [saveGame] in
            await saveGame(snapshot)
        }
    }
}

// MARK: - Session restoration & peer lookup

private extension GameViewModel {
    /// Resumes the saved session for the launch context, or starts a new one.
    func restoreOrStartSession(now: Date) async -> GameSession? {
        switch launch.kind {
        case .resume:
            return await resumeGame(context: .regular)

        case let .new(variant, difficulty, mode):
            return await startGame(
                variant: variant,
                difficulty: difficulty,
                mode: mode,
                context: .regular,
                at: now,
            )

        case let .daily(dateKey, variant, difficulty):
            let context = GameContext.daily(dateKey: dateKey, variant: variant)
            if let saved = await resumeGame(context: context) {
                return saved
            }
            return await startGame(
                variant: variant,
                difficulty: difficulty,
                mode: .normal,
                context: context,
                at: now,
            )

        case let .weekly(variant, difficulty):
            let context = GameContext.weekly(weekKey: EventSeeds.weekKey(for: now))
            if let saved = await resumeGame(context: context) {
                return saved
            }
            return await startGame(
                variant: variant,
                difficulty: difficulty,
                mode: .normal,
                context: context,
                at: now,
            )
        }
    }

    static func buildPeers(for puzzle: PuzzleDefinition) -> [[Int]] {
        let gridTopology = TopologyFactory.topology(for: puzzle)
        var peers = [Set<Int>](repeating: [], count: gridTopology.cellCount)
        for house in gridTopology.houses {
            for cell in house {
                peers[cell].formUnion(house)
            }
        }
        for clique in gridTopology.cliques {
            for cell in clique {
                peers[cell].formUnion(clique)
            }
        }
        for cage in puzzle.cages {
            for cell in cage.cells {
                peers[cell].formUnion(cage.cells)
            }
        }
        return peers.enumerated().map { cell, set in
            set.subtracting([cell]).sorted()
        }
    }
}
