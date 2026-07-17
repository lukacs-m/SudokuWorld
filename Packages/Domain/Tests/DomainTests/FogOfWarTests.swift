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
        #expect(session.revealedCells == GameSession.initialFog(for: session.puzzle))
        // Non-fog variants have no fog at all.
        let classic = PuzzleGenerator().generateNow(variant: .classic, difficulty: .easy, seed: 6)
        #expect(GameSession.initialFog(for: classic).isEmpty)
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
            of: GameSession.fogNeighborhood(of: cell, puzzle: session.puzzle),
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
}
