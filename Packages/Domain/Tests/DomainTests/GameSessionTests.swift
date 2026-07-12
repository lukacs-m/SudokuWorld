import Foundation
import Testing
@testable import Domain
import Model

/// A tiny handcrafted classic puzzle wrapper for session tests, built on the
/// known Wikipedia grid so solution lookups are stable.
private func makeSession(mode: GameMode = .normal, startedAt: Date = .epoch) -> GameSession {
    let puzzle = PuzzleDefinition(
        id: UUID(),
        variant: .classic,
        requestedDifficulty: .easy,
        gradedDifficulty: .easy,
        seed: 1,
        givens: Fixtures.classicGivens,
        solution: Fixtures.classicSolution,
    )
    return GameSession(puzzle: puzzle, mode: mode, context: .regular, startedAt: startedAt)
}

private extension Date {
    static let epoch = Date(timeIntervalSince1970: 1_750_000_000)
}

/// First empty cell index of the fixture puzzle.
private func firstEmpty(_ session: GameSession) -> Int {
    (0..<session.board.count).first { session.board[$0].value == nil } ?? 0
}

@Suite
struct GameSessionTests {
    @Test func correctPlacementIsAccepted() {
        var session = makeSession()
        let index = firstEmpty(session)
        let result = session.place(
            session.puzzle.solution[index],
            at: index,
            autoCleanNotes: true,
        )
        #expect(result == .placed)
        #expect(session.board[index].value == session.puzzle.solution[index])
        #expect(session.mistakes == 0)
    }

    @Test func wrongPlacementCountsAMistake() {
        var session = makeSession()
        let index = firstEmpty(session)
        let wrong = session.puzzle.solution[index] == 1 ? 2 : 1
        let result = session.place(wrong, at: index, autoCleanNotes: true)
        #expect(result == .mistake(total: 1))
        #expect(session.mistakes == 1)
    }

    @Test func givensAreImmutable() {
        var session = makeSession()
        let givenIndex = (0..<session.board.count).first { session.board[$0].isGiven } ?? 0
        #expect(session.place(1, at: givenIndex, autoCleanNotes: true) == .rejected)
        #expect(session.toggleNote(1, at: givenIndex) == .rejected)
        #expect(session.clear(at: givenIndex) == .rejected)
    }

    @Test func hardcoreLossOnFourthMistake() {
        var session = makeSession(mode: .hardcore)
        let index = firstEmpty(session)
        let wrong = session.puzzle.solution[index] == 1 ? 2 : 1

        #expect(session.place(wrong, at: index, autoCleanNotes: true) == .mistake(total: 1))
        _ = session.clear(at: index)
        #expect(session.place(wrong, at: index, autoCleanNotes: true) == .mistake(total: 2))
        _ = session.clear(at: index)
        #expect(session.place(wrong, at: index, autoCleanNotes: true) == .mistake(total: 3))
        _ = session.clear(at: index)
        #expect(session.place(wrong, at: index, autoCleanNotes: true) == .hardcoreLoss)
        #expect(session.isLost)
        #expect(session.isOver)
        // Game over: every further interaction is rejected.
        #expect(session.place(wrong, at: index, autoCleanNotes: true) == .rejected)
        let undone = session.undo()
        #expect(!undone)
    }

    @Test func autoCleanRemovesPeerNotesAndUndoRestoresThem() {
        var session = makeSession()
        let index = firstEmpty(session)
        let digit = session.puzzle.solution[index]

        // Find an empty peer sharing the row.
        let topology = TopologyFactory.topology(for: .classic)
        let position = topology.position(of: index)
        let peer = (0..<9)
            .compactMap { topology.index(row: position.row, col: $0) }
            .first { $0 != index && session.board[$0].value == nil }
        guard let peer else {
            Issue.record("No empty peer found")
            return
        }

        _ = session.toggleNote(digit, at: peer)
        _ = session.toggleNote(5, at: peer)
        #expect(session.board[peer].notes.contains(digit))

        _ = session.place(digit, at: index, autoCleanNotes: true)
        #expect(!session.board[peer].notes.contains(digit))

        // Undo the placement: the peer's notes come back exactly.
        // (The last move is the placement; the two note toggles preceded it.)
        let undone = session.undo()
        #expect(undone)
        #expect(session.board[index].value == nil)
        #expect(session.board[peer].notes.contains(digit))
        #expect(session.board[peer].notes.contains(5))

        // Redo re-applies both the value and the note cleaning.
        let redone = session.redo()
        #expect(redone)
        #expect(session.board[index].value == digit)
        #expect(!session.board[peer].notes.contains(digit))
        #expect(session.board[peer].notes.contains(5))
    }

    @Test func undoRedoStacksBehave() {
        var session = makeSession()
        let index = firstEmpty(session)
        #expect(!session.canUndo)
        #expect(!session.canRedo)

        _ = session.place(session.puzzle.solution[index], at: index, autoCleanNotes: false)
        #expect(session.canUndo)
        #expect(!session.canRedo)

        let undone = session.undo()
        #expect(undone)
        #expect(session.canRedo)
        #expect(session.board[index].value == nil)

        // A fresh move clears the redo stack.
        _ = session.toggleNote(3, at: index)
        #expect(!session.canRedo)
    }

    @Test func solvingTheLastCellReportsSolved() {
        var session = makeSession()
        // Fill everything but one cell.
        let empties = (0..<session.board.count).filter { session.board[$0].value == nil }
        for index in empties.dropLast() {
            _ = session.place(session.puzzle.solution[index], at: index, autoCleanNotes: false)
        }
        guard let last = empties.last else {
            Issue.record("Fixture has no empty cells")
            return
        }
        let result = session.place(session.puzzle.solution[last], at: last, autoCleanNotes: false)
        #expect(result == .solved)
        #expect(session.isSolved)
        #expect(session.isOver)
    }

    @Test func clockPausesAndResumes() {
        let start = Date.epoch
        var session = makeSession(startedAt: start)

        let oneMinuteIn = start.addingTimeInterval(60)
        #expect(session.elapsed(at: oneMinuteIn) == 60)

        session.pause(at: oneMinuteIn)
        // Backgrounded time doesn't count.
        let tenMinutesLater = oneMinuteIn.addingTimeInterval(600)
        #expect(session.elapsed(at: tenMinutesLater) == 60)

        session.resume(at: tenMinutesLater)
        let thirtySecondsMore = tenMinutesLater.addingTimeInterval(30)
        #expect(session.elapsed(at: thirtySecondsMore) == 90)
    }

    @Test func savedGameRoundtripRestoresState() {
        let start = Date.epoch
        var session = makeSession(startedAt: start)
        let index = firstEmpty(session)
        _ = session.place(session.puzzle.solution[index], at: index, autoCleanNotes: false)
        _ = session.toggleNote(4, at: firstEmpty(session))

        let saveTime = start.addingTimeInterval(120)
        let snapshot = session.savedGame(at: saveTime)
        #expect(snapshot.elapsed == 120)

        let restored = GameSession(restoring: snapshot)
        #expect(restored.board == session.board)
        #expect(restored.undoStack == session.undoStack)
        #expect(restored.mistakes == session.mistakes)
        // Restored sessions are paused until play resumes.
        #expect(restored.elapsed(at: saveTime.addingTimeInterval(999)) == 120)

        // Undo still works across the roundtrip (note toggle, then placement).
        var resumed = restored
        let firstUndo = resumed.undo()
        let secondUndo = resumed.undo()
        #expect(firstUndo)
        #expect(secondUndo)
        #expect(resumed.board[index].value == nil)
    }

    @Test func applyRevealHintFixesWrongCell() {
        var session = makeSession()
        let index = firstEmpty(session)
        let wrong = session.puzzle.solution[index] == 1 ? 2 : 1
        _ = session.place(wrong, at: index, autoCleanNotes: false)

        let hint = Hint(
            kind: .reveal,
            cells: [index],
            placement: Hint.Placement(index: index, digit: session.puzzle.solution[index]),
            explanationKey: "hint.reveal",
        )
        let result = session.applyHint(hint, autoCleanNotes: false)
        #expect(result == .placed)
        #expect(session.board[index].value == session.puzzle.solution[index])
        #expect(session.hintsUsed == 1)
        #expect(session.usedReveal)
    }
}
