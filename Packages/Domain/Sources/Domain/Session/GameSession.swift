public import Foundation
public import Model

/// The live state of one game: board, undo/redo history, mistakes, hints,
/// and timing. A pure value type — the ViewModel owns an instance on the
/// MainActor and injects every `Date`, which keeps all rules unit-testable
/// and makes autosave a straight serialization of this struct.
public struct GameSession: Equatable, Sendable {
    public let puzzle: PuzzleDefinition
    public let mode: GameMode
    public let context: GameContext
    public let startedAt: Date

    public private(set) var board: Board
    public private(set) var undoStack: [Move]
    public private(set) var redoStack: [Move]
    public private(set) var mistakes: Int
    public private(set) var hintsUsed: Int
    public private(set) var usedReveal: Bool
    public private(set) var isLost: Bool

    /// Play time accumulated across pauses; never counts backgrounded time.
    public private(set) var accumulated: TimeInterval
    /// Set while the clock is running.
    public private(set) var lastResume: Date?

    /// Fog-of-war reveal state: cells the player can see. Starts as a few
    /// seeded windows; every correct placement lifts the fog around itself.
    /// Reveals never revert — not even through undo. Empty for other
    /// variants.
    public private(set) var revealedCells: Set<Int>

    private let detector: ConflictDetector

    // MARK: - Lifecycle

    /// A fresh game, with the clock running from `startedAt`.
    public init(puzzle: PuzzleDefinition, mode: GameMode, context: GameContext, startedAt: Date) {
        self.puzzle = puzzle
        self.mode = mode
        self.context = context
        self.startedAt = startedAt
        board = Board(puzzle: puzzle)
        undoStack = []
        redoStack = []
        mistakes = 0
        hintsUsed = 0
        usedReveal = false
        isLost = false
        accumulated = 0
        lastResume = startedAt
        revealedCells = Self.initialFog(for: puzzle)
        detector = ConflictDetector(puzzle: puzzle)
    }

    /// Restores a saved game, paused — call `resume(at:)` when play begins.
    public init(restoring saved: SavedGame) {
        puzzle = saved.puzzle
        mode = saved.mode
        context = saved.context
        startedAt = saved.startedAt
        board = saved.board
        undoStack = saved.undoStack
        redoStack = saved.redoStack
        mistakes = saved.mistakes
        hintsUsed = saved.hintsUsed
        usedReveal = saved.usedReveal
        isLost = false
        accumulated = saved.elapsed
        lastResume = nil
        if let restored = saved.revealedCells {
            revealedCells = Set(restored)
        } else {
            // Saves that predate the field: re-derive deterministically —
            // the seeded windows plus the fog lifted by every correct
            // placement already on the board.
            var reveals = Self.initialFog(for: saved.puzzle)
            if saved.puzzle.variant == .fogOfWar {
                for index in 0 ..< saved.board.count
                    where !saved.board[index].isGiven
                    && saved.board[index].value == saved.puzzle.solution[index]
                {
                    reveals.formUnion(Self.fogNeighborhood(of: index, puzzle: saved.puzzle))
                }
            }
            revealedCells = reveals
        }
        detector = ConflictDetector(puzzle: puzzle)
    }

    // MARK: - Fog of war

    /// Whether a cell is still hidden by fog.
    public func isFogged(_ index: Int) -> Bool {
        puzzle.variant == .fogOfWar && !revealedCells.contains(index)
    }

    /// Three seeded 3×3 windows give the player a foothold.
    static func initialFog(for puzzle: PuzzleDefinition) -> Set<Int> {
        guard puzzle.variant == .fogOfWar else { return [] }
        let size = Int(Double(puzzle.solution.count).squareRoot())
        var rng = SplitMix64(seed: puzzle.seed)
        var revealed = Set<Int>()
        for _ in 0 ..< 3 {
            let originRow = Int(rng.next() % UInt64(size - 2))
            let originCol = Int(rng.next() % UInt64(size - 2))
            for row in originRow ..< (originRow + 3) {
                for col in originCol ..< (originCol + 3) {
                    revealed.insert(row * size + col)
                }
            }
        }
        return revealed
    }

    /// The 3×3 neighborhood a correct placement reveals.
    static func fogNeighborhood(of index: Int, puzzle: PuzzleDefinition) -> Set<Int> {
        let size = Int(Double(puzzle.solution.count).squareRoot())
        let row = index / size
        let col = index % size
        var cells = Set<Int>()
        for dr in -1 ... 1 {
            for dc in -1 ... 1 {
                let r = row + dr
                let c = col + dc
                guard r >= 0, r < size, c >= 0, c < size else { continue }
                cells.insert(r * size + c)
            }
        }
        return cells
    }

    // MARK: - State

    public var isSolved: Bool {
        detector.isSolved(board)
    }

    public var isOver: Bool {
        isSolved || isLost
    }

    /// Cells currently violating a rule (duplicates, parity, bad cage sums).
    public func conflicts() -> Set<Int> {
        detector.conflicts(in: board)
    }

    // MARK: - Moves

    /// Places a digit. Wrong digits count as mistakes; in hardcore mode,
    /// exceeding the mistake limit loses the game.
    public mutating func place(_ digit: Int, at index: Int, autoCleanNotes: Bool) -> MoveResult {
        guard !isOver, board.cells.indices.contains(index) else { return .rejected }
        let before = board[index]
        guard !before.isGiven, before.value != digit else { return .rejected }

        var after = before
        after.value = digit
        after.notes = CellNotes()

        var clearedPeerNotes: [Int: CellNotes] = [:]
        if autoCleanNotes {
            for peer in detector.peers[index]
                where board[peer].value == nil && board[peer].notes.contains(digit)
            {
                clearedPeerNotes[peer] = board[peer].notes
            }
        }

        board[index] = after
        for peer in clearedPeerNotes.keys {
            board[peer].notes.remove(digit)
        }
        undoStack.append(Move(
            index: index,
            before: before,
            after: after,
            clearedPeerNotes: clearedPeerNotes,
        ))
        redoStack = []

        if digit != puzzle.solution[index] {
            mistakes += 1
            if let limit = mode.maxMistakes, mistakes > limit {
                isLost = true
                return .hardcoreLoss
            }
            return .mistake(total: mistakes)
        }
        if puzzle.variant == .fogOfWar {
            revealedCells.formUnion(Self.fogNeighborhood(of: index, puzzle: puzzle))
        }
        if isSolved {
            return .solved
        }
        return .placed
    }

    /// Toggles a pencil note on an empty cell.
    public mutating func toggleNote(_ digit: Int, at index: Int) -> MoveResult {
        guard !isOver, board.cells.indices.contains(index) else { return .rejected }
        let before = board[index]
        guard !before.isGiven, before.value == nil else { return .rejected }

        var after = before
        after.notes.toggle(digit)
        board[index] = after
        undoStack.append(Move(index: index, before: before, after: after))
        redoStack = []
        return .placed
    }

    /// Clears a cell's value, or its notes when it has no value.
    public mutating func clear(at index: Int) -> MoveResult {
        guard !isOver, board.cells.indices.contains(index) else { return .rejected }
        let before = board[index]
        guard !before.isGiven, before.value != nil || !before.notes.isEmpty else {
            return .rejected
        }

        var after = before
        if after.value != nil {
            after.value = nil
        } else {
            after.notes = CellNotes()
        }
        board[index] = after
        undoStack.append(Move(index: index, before: before, after: after))
        redoStack = []
        return .placed
    }

    /// Applies a hint: placements go through the regular move path (and are
    /// always correct), eliminations prune the player's pencil notes.
    public mutating func applyHint(_ hint: Hint, autoCleanNotes: Bool) -> MoveResult {
        guard !isOver else { return .rejected }
        hintsUsed += 1
        if case .reveal = hint.kind {
            usedReveal = true
        }

        if let placement = hint.placement {
            // A revealed cell may currently hold a wrong value — clear first.
            if board[placement.index].value != nil {
                _ = clear(at: placement.index)
            }
            return place(placement.digit, at: placement.index, autoCleanNotes: autoCleanNotes)
        }
        for elimination in hint.eliminations
            where board[elimination.index].notes.contains(elimination.digit)
        {
            board[elimination.index].notes.remove(elimination.digit)
        }
        return .placed
    }

    // MARK: - Undo / redo

    @discardableResult
    public mutating func undo() -> Bool {
        guard !isOver, let move = undoStack.popLast() else { return false }
        board[move.index] = move.before
        for (peer, notes) in move.clearedPeerNotes {
            board[peer].notes = notes
        }
        redoStack.append(move)
        return true
    }

    @discardableResult
    public mutating func redo() -> Bool {
        guard !isOver, let move = redoStack.popLast() else { return false }
        board[move.index] = move.after
        if let digit = move.after.value {
            for peer in move.clearedPeerNotes.keys {
                board[peer].notes.remove(digit)
            }
        }
        undoStack.append(move)
        return true
    }

    public var canUndo: Bool {
        !undoStack.isEmpty && !isOver
    }

    public var canRedo: Bool {
        !redoStack.isEmpty && !isOver
    }

    // MARK: - Clock

    public mutating func pause(at now: Date) {
        guard let resumedAt = lastResume else { return }
        accumulated += max(0, now.timeIntervalSince(resumedAt))
        lastResume = nil
    }

    public mutating func resume(at now: Date) {
        guard lastResume == nil, !isOver else { return }
        lastResume = now
    }

    /// The clock keeps running through terminal moves; the ViewModel calls
    /// `pause(at:)` with a real date immediately after a solved/lost result
    /// and reads the final time via `elapsed(at:)`.
    public func elapsed(at now: Date) -> TimeInterval {
        accumulated + (lastResume.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    // MARK: - Persistence

    /// A snapshot for autosave. `elapsed` captures the running clock at `now`.
    public func savedGame(at now: Date) -> SavedGame {
        SavedGame(
            context: context,
            mode: mode,
            puzzle: puzzle,
            board: board,
            undoStack: undoStack,
            redoStack: redoStack,
            elapsed: elapsed(at: now),
            mistakes: mistakes,
            hintsUsed: hintsUsed,
            usedReveal: usedReveal,
            startedAt: startedAt,
            updatedAt: now,
            revealedCells: puzzle.variant == .fogOfWar ? revealedCells.sorted() : nil,
        )
    }
}
