import Common
public import Foundation
public import Model

// MARK: - Start

/// Starts a new game: generates the puzzle off-main, builds the session, and
/// persists an initial snapshot so "Continue" picks it up immediately.
public protocol StartGameUseCase: Sendable {
    func callAsFunction(
        variant: SudokuVariant,
        difficulty: Difficulty,
        mode: GameMode,
        context: GameContext,
        at now: Date,
    ) async -> GameSession
}

public struct StartGame: StartGameUseCase {
    private let savedGames: any SavedGameRepository
    private let generator = PuzzleGenerator()

    public init(savedGames: any SavedGameRepository) {
        self.savedGames = savedGames
    }

    public func callAsFunction(
        variant: SudokuVariant,
        difficulty: Difficulty,
        mode: GameMode,
        context: GameContext,
        at now: Date,
    ) async -> GameSession {
        let seed: UInt64 = switch context {
        case let .daily(dateKey):
            // The shared worldwide seed — every player gets the same board.
            EventSeeds.dailySeed(dateKey: dateKey)

        case .regular, .weekly:
            Self.entropySeed(from: now)
        }
        let puzzle = await generator.generate(variant: variant, difficulty: difficulty, seed: seed)
        let session = GameSession(puzzle: puzzle, mode: mode, context: context, startedAt: now)
        try? await savedGames.save(session.savedGame(at: now))
        return session
    }

    /// Regular games draw their seed from the start time. Still funneled
    /// through the deterministic mixer — the engine never touches the
    /// system RNG.
    static func entropySeed(from date: Date) -> UInt64 {
        SplitMix64.evolve(UInt64(bitPattern: Int64(date.timeIntervalSince1970 * 1_000_000)))
    }
}

// MARK: - Resume

/// Restores the saved game for a context, if one exists. The session comes
/// back paused; the game screen resumes the clock when play begins.
public protocol ResumeGameUseCase: Sendable {
    func callAsFunction(context: GameContext) async -> GameSession?
}

public struct ResumeGame: ResumeGameUseCase {
    private let savedGames: any SavedGameRepository

    public init(savedGames: any SavedGameRepository) {
        self.savedGames = savedGames
    }

    public func callAsFunction(context: GameContext) async -> GameSession? {
        guard let saved = try? await savedGames.load(context: context) else { return nil }
        return GameSession(restoring: saved)
    }
}

// MARK: - Save

/// Persists an autosave snapshot. Failures are logged, never surfaced —
/// autosave must stay invisible to play.
public protocol SaveGameUseCase: Sendable {
    func callAsFunction(_ snapshot: SavedGame) async
}

public struct SaveGame: SaveGameUseCase {
    private let savedGames: any SavedGameRepository

    public init(savedGames: any SavedGameRepository) {
        self.savedGames = savedGames
    }

    public func callAsFunction(_ snapshot: SavedGame) async {
        do {
            try await savedGames.save(snapshot)
        } catch {
            Log.error("Autosave failed: \(error)")
        }
    }
}

// MARK: - Abandon

/// Records an abandoned game and clears its saved state.
public protocol AbandonGameUseCase: Sendable {
    func callAsFunction(session: GameSession, at now: Date) async
}

public struct AbandonGame: AbandonGameUseCase {
    private let savedGames: any SavedGameRepository
    private let gameRecords: any GameRecordRepository

    public init(savedGames: any SavedGameRepository, gameRecords: any GameRecordRepository) {
        self.savedGames = savedGames
        self.gameRecords = gameRecords
    }

    public func callAsFunction(session: GameSession, at now: Date) async {
        let record = GameRecord(
            id: UUID(),
            variant: session.puzzle.variant,
            difficulty: session.puzzle.requestedDifficulty,
            mode: session.mode,
            outcome: .abandoned,
            context: session.context,
            duration: session.elapsed(at: now),
            mistakes: session.mistakes,
            hintsUsed: session.hintsUsed,
            usedReveal: session.usedReveal,
            points: 0,
            startedAt: session.startedAt,
            finishedAt: now,
        )
        try? await gameRecords.insert(record)
        try? await savedGames.delete(context: session.context)
    }
}
