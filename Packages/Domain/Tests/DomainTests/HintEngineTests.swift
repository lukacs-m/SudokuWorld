import Testing
@testable import Domain
import Model

@Suite
struct HintEngineTests {
    private let engine = HintEngine()
    private let generator = PuzzleGenerator()

    private var puzzle: PuzzleDefinition {
        generator.generateNow(variant: .classic, difficulty: .easy, seed: 777)
    }

    @Test func freshBoardGetsALogicalHint() {
        let puzzle = puzzle
        let board = Board(puzzle: puzzle)
        let hint = engine.nextHint(board: board, puzzle: puzzle)

        guard let hint else {
            Issue.record("Expected a hint on a fresh, solvable board")
            return
        }
        if case .reveal = hint.kind {
            Issue.record("Expected a logical hint, got a reveal fallback")
        }
        // A hint always changes something.
        #expect(hint.placement != nil || !hint.eliminations.isEmpty)
        #expect(!hint.cells.isEmpty)
        #expect(!hint.explanationKey.isEmpty)
    }

    @Test func hintPlacementsMatchTheSolution() {
        let puzzle = puzzle
        var board = Board(puzzle: puzzle)
        // Follow placement hints for a stretch; every one must be correct.
        for _ in 0..<10 {
            guard let hint = engine.nextHint(board: board, puzzle: puzzle) else { break }
            if let placement = hint.placement {
                #expect(placement.digit == puzzle.solution[placement.index])
                board[placement.index].value = placement.digit
            } else {
                break
            }
        }
    }

    @Test func wrongEntryTriggersMistakeHint() {
        let puzzle = puzzle
        var board = Board(puzzle: puzzle)
        guard let emptyIndex = (0..<board.count).first(where: { board[$0].value == nil }) else {
            Issue.record("Puzzle has no empty cell")
            return
        }
        let wrong = puzzle.solution[emptyIndex] == 1 ? 2 : 1
        board[emptyIndex].value = wrong

        let hint = engine.nextHint(board: board, puzzle: puzzle)
        #expect(hint?.kind == .reveal)
        #expect(hint?.explanationKey == "hint.mistake")
        #expect(hint?.cells == [emptyIndex])
        #expect(hint?.placement?.digit == puzzle.solution[emptyIndex])
    }

    @Test func revealHintPrefersTheRequestedCell() {
        let puzzle = puzzle
        let board = Board(puzzle: puzzle)
        guard let emptyIndex = (0..<board.count).first(where: { board[$0].value == nil }) else {
            Issue.record("Puzzle has no empty cell")
            return
        }
        let hint = engine.revealHint(preferredCell: emptyIndex, board: board, puzzle: puzzle)
        #expect(hint?.kind == .reveal)
        #expect(hint?.placement?.index == emptyIndex)
        #expect(hint?.placement?.digit == puzzle.solution[emptyIndex])
    }

    @Test func revealHintSkipsGivens() {
        let puzzle = puzzle
        let board = Board(puzzle: puzzle)
        guard let givenIndex = (0..<board.count).first(where: { board[$0].isGiven }) else {
            Issue.record("Puzzle has no givens")
            return
        }
        let hint = engine.revealHint(preferredCell: givenIndex, board: board, puzzle: puzzle)
        // Falls back to some other revealable cell instead.
        #expect(hint != nil)
        #expect(hint?.placement?.index != givenIndex)
    }

    @Test func completedBoardYieldsNoHint() {
        let puzzle = puzzle
        var board = Board(puzzle: puzzle)
        for index in 0..<board.count where board[index].value == nil {
            board[index].value = puzzle.solution[index]
        }
        #expect(engine.nextHint(board: board, puzzle: puzzle) == nil)
        #expect(engine.revealHint(preferredCell: nil, board: board, puzzle: puzzle) == nil)
    }
}
