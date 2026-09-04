import Foundation
import Testing
@testable import Domain
import Model

/// Fog-of-war session mechanics: seeded windows, reveal on correct
/// placement, no re-fogging, and persistence round-trips.
@Suite
struct FogOfWarTests {
    private func freshSession() -> GameSession {
        let puzzle = PuzzleGenerator().generateNow(variant: .fogOfWar, difficulty: .easy, seed: 6)
        return GameSession(
            puzzle: puzzle,
            mode: .normal,
            context: .regular,
            startedAt: Date(timeIntervalSince1970: 0),
        )
    }

    @Test func freshGamesStartWithSeededWindows() {
        let session = freshSession()
        #expect(!session.revealedCells.isEmpty)
        #expect(session.revealedCells.count < 81)
        // Deterministic per seed.
        #expect(session.revealedCells == FogOfWar.initialWindows(for: session.puzzle))
        // Non-fog variants have no fog at all.
        let classic = PuzzleGenerator().generateNow(variant: .classic, difficulty: .easy, seed: 6)
        #expect(FogOfWar.initialWindows(for: classic).isEmpty)
    }

    @Test func correctPlacementLiftsTheFogAround() {
        var session = freshSession()
        guard let cell = session.revealedCells.first(where: {
            session.puzzle.givens[$0] == nil && session.board[$0].value == nil
        }) else {
            Issue.record("no open revealed cell")
            return
        }
        let before = session.revealedCells
        _ = session.place(session.puzzle.solution[cell], at: cell, autoCleanNotes: false)
        #expect(session.revealedCells.isSuperset(of: before))
        #expect(session.revealedCells.isSuperset(
            of: FogOfWar.neighborhood(of: cell, puzzle: session.puzzle),
        ))
    }

    @Test func wrongPlacementRevealsNothingAndUndoNeverRefogs() {
        var session = freshSession()
        guard let cell = session.revealedCells.first(where: {
            session.puzzle.givens[$0] == nil && session.board[$0].value == nil
        }) else {
            Issue.record("no open revealed cell")
            return
        }
        let before = session.revealedCells
        let wrong = session.puzzle.solution[cell] == 9 ? 8 : session.puzzle.solution[cell] + 1
        _ = session.place(wrong, at: cell, autoCleanNotes: false)
        #expect(session.revealedCells == before)

        _ = session.clear(at: cell)
        _ = session.place(session.puzzle.solution[cell], at: cell, autoCleanNotes: false)
        let afterReveal = session.revealedCells
        session.undo()
        #expect(session.revealedCells == afterReveal, "undo must not re-fog")
    }

    @Test func revealStateRoundTripsThroughSaves() throws {
        var session = freshSession()
        guard let cell = session.revealedCells.first(where: {
            session.puzzle.givens[$0] == nil && session.board[$0].value == nil
        }) else {
            Issue.record("no open revealed cell")
            return
        }
        _ = session.place(session.puzzle.solution[cell], at: cell, autoCleanNotes: false)

        let saved = session.savedGame(at: Date(timeIntervalSince1970: 60))
        #expect(saved.revealedCells != nil)
        let restored = GameSession(restoring: saved)
        #expect(restored.revealedCells == session.revealedCells)

        // A pre-fog save (nil payload) re-derives deterministically.
        let legacy = SavedGame(
            context: saved.context,
            mode: saved.mode,
            puzzle: saved.puzzle,
            board: saved.board,
            undoStack: saved.undoStack,
            redoStack: saved.redoStack,
            elapsed: saved.elapsed,
            mistakes: saved.mistakes,
            hintsUsed: saved.hintsUsed,
            usedReveal: saved.usedReveal,
            startedAt: saved.startedAt,
            updatedAt: saved.updatedAt,
            revealedCells: nil,
        )
        let rederived = GameSession(restoring: legacy)
        #expect(rederived.revealedCells == session.revealedCells)
    }

    @Test func foggedLookupMatchesRevealSet() {
        let session = freshSession()
        for cell in 0 ..< 81 {
            #expect(session.isFogged(cell) == !session.revealedCells.contains(cell))
        }
    }

    // MARK: - Fair fog (Expert and Master)

    private func fairSession(difficulty: Difficulty = .expert, seed: UInt64 = 3) -> GameSession {
        let puzzle = PuzzleGenerator().generateNow(variant: .fogOfWar, difficulty: difficulty, seed: seed)
        return GameSession(
            puzzle: puzzle,
            mode: .normal,
            context: .regular,
            startedAt: Date(timeIntervalSince1970: 0),
        )
    }

    /// The easiest logical placement available in the visible position.
    private func logicalPlacement(_ session: GameSession) -> (cell: Int, digit: Int)? {
        FogOfWar.firstVisiblePlacement(
            puzzle: session.puzzle,
            board: session.board,
            revealed: session.revealedCells,
        )
    }

    @Test func hardKeepsTheClassicMechanic() {
        var session = fairSession(difficulty: .hard)
        #expect(!FogOfWar.isFair(session.puzzle))
        #expect(session.revealedCells == FogOfWar.seededWindows(for: session.puzzle, count: 3))
        #expect(session.fogAutoReveals == 0)

        guard let cell = session.revealedCells.sorted().first(where: {
            session.puzzle.givens[$0] == nil
        }) else {
            Issue.record("no open revealed cell")
            return
        }
        let before = session.revealedCells
        _ = session.place(session.puzzle.solution[cell], at: cell, autoCleanNotes: false)
        #expect(session.revealedCells == before.union(FogOfWar.neighborhood(of: cell, puzzle: session.puzzle)))
    }

    @Test(arguments: [Difficulty.expert, .master])
    func fairGamesStartWiderAndRevealWholeHouses(difficulty: Difficulty) {
        var session = fairSession(difficulty: difficulty)
        #expect(FogOfWar.isFair(session.puzzle))
        let classicStart = FogOfWar.seededWindows(for: session.puzzle, count: 3)
        #expect(session.revealedCells.isStrictSuperset(of: classicStart))
        #expect(session.revealedCells.count < 81)

        guard let step = logicalPlacement(session) else {
            Issue.record("fresh fair game has no logical step")
            return
        }
        let before = session.revealedCells
        _ = session.place(step.digit, at: step.cell, autoCleanNotes: false)
        let houses = FogOfWar.houses(of: step.cell, puzzle: session.puzzle)
        #expect(houses.count == 21)
        #expect(session.revealedCells.isSuperset(of: before.union(houses)))
    }

    @Test func fairGamesNeverStartStuck() {
        for seed in 1 ... 10 as ClosedRange<UInt64> {
            let session = fairSession(difficulty: .master, seed: seed)
            #expect(logicalPlacement(session) != nil, "seed \(seed)")
        }
    }

    @Test func autoRevealIsDeterministicAndSurvivesRestore() {
        var session = fairSession()
        let saved = session.savedGame(at: Date(timeIntervalSince1970: 60))
        var restored = GameSession(restoring: saved)
        #expect(restored.revealedCells == session.revealedCells)
        // The counter is session-local; only the reveal set persists.
        let liftsBeforeSave = session.fogAutoReveals
        #expect(restored.fogAutoReveals == 0)

        // The same logic-only moves on both copies must lift exactly the
        // same fog, auto-reveals included.
        for _ in 0 ..< 8 {
            guard let step = logicalPlacement(session) else {
                Issue.record("stuck")
                return
            }
            _ = session.place(step.digit, at: step.cell, autoCleanNotes: false)
            _ = restored.place(step.digit, at: step.cell, autoCleanNotes: false)
            #expect(restored.revealedCells == session.revealedCells)
            #expect(restored.fogAutoReveals == session.fogAutoReveals - liftsBeforeSave)
        }
        let again = FogOfWar.autoReveal(
            puzzle: session.puzzle,
            board: session.board,
            revealed: session.revealedCells,
        )
        #expect(again == FogOfWar.autoReveal(
            puzzle: session.puzzle,
            board: session.board,
            revealed: session.revealedCells,
        ))
    }

    @Test func legacySavesRederiveUnderTheCurrentRules() {
        var session = fairSession()
        guard let step = logicalPlacement(session) else {
            Issue.record("stuck")
            return
        }
        _ = session.place(step.digit, at: step.cell, autoCleanNotes: false)
        let saved = session.savedGame(at: Date(timeIntervalSince1970: 60))
        let legacy = SavedGame(
            context: saved.context,
            mode: saved.mode,
            puzzle: saved.puzzle,
            board: saved.board,
            undoStack: saved.undoStack,
            redoStack: saved.redoStack,
            elapsed: saved.elapsed,
            mistakes: saved.mistakes,
            hintsUsed: saved.hintsUsed,
            usedReveal: saved.usedReveal,
            startedAt: saved.startedAt,
            updatedAt: saved.updatedAt,
            revealedCells: nil,
        )
        // Auto-reveals depend on when they happened, so the exact set is
        // not reproducible without the field — but the windows, the house
        // reveal, and the never-stuck guarantee all hold.
        let rederived = GameSession(restoring: legacy)
        #expect(rederived.revealedCells.isSuperset(of: FogOfWar.initialWindows(for: session.puzzle)))
        #expect(rederived.revealedCells.isSuperset(of: FogOfWar.houses(of: step.cell, puzzle: session.puzzle)))
        #expect(logicalPlacement(rederived) != nil)
    }

    /// The proof: a logic-only player — always the easiest step the
    /// technique ladder finds in the visible position, never a guess —
    /// finishes every Expert and Master game. Prints the auto-reveal
    /// counts the PR reports.
    @Test(arguments: [Difficulty.expert, .master])
    func logicOnlyPlayerFinishesEveryFairGame(difficulty: Difficulty) {
        var autoReveals: [UInt64: Int] = [:]
        for seed in 1 ... 25 as ClosedRange<UInt64> {
            var session = fairSession(difficulty: difficulty, seed: seed)
            while !session.isSolved {
                guard let step = logicalPlacement(session) else {
                    Issue.record("seed \(seed): stuck by logic with \(session.board.filledCount) cells")
                    break
                }
                let result = session.place(step.digit, at: step.cell, autoCleanNotes: false)
                #expect(result == .placed || result == .solved, "seed \(seed)")
            }
            #expect(session.isSolved, "seed \(seed)")
            #expect(session.mistakes == 0)
            autoReveals[seed] = session.fogAutoReveals
        }
        let counts = autoReveals.values
        print(
            "fog-of-war \(difficulty): auto-reveals total \(counts.reduce(0, +)),",
            "games needing any \(counts.count { $0 > 0 })/25,",
            "max per game \(counts.max() ?? 0)",
        )
    }
}
