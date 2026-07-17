import Testing
@testable import Domain
import Model

/// Anti-knight and anti-king ride on topology cliques: every generated
/// solution must honor the movement rule, and the conflict detector must
/// flag violations the player creates.
@Suite
struct ChessVariantTests {
    @Test(arguments: [UInt64(1), 77, 4242])
    func antiKnightSolutionsHaveNoKnightRepeats(seed: UInt64) {
        let puzzle = PuzzleGenerator().generateNow(
            variant: .antiKnight,
            difficulty: .easy,
            seed: seed,
        )
        for row in 0 ..< 9 {
            for col in 0 ..< 9 {
                for (dr, dc) in [(1, 2), (1, -2), (2, 1), (2, -1)] {
                    let r = row + dr
                    let c = col + dc
                    guard r >= 0, r < 9, c >= 0, c < 9 else { continue }
                    #expect(
                        puzzle.solution[row * 9 + col] != puzzle.solution[r * 9 + c],
                        "knight repeat at r\(row)c\(col) ↔ r\(r)c\(c)",
                    )
                }
            }
        }
    }

    @Test func antiKingSolutionsHaveNoDiagonalTouchRepeats() {
        let puzzle = PuzzleGenerator().generateNow(
            variant: .antiKing,
            difficulty: .easy,
            seed: 7,
        )
        for row in 0 ..< 8 {
            for col in 0 ..< 9 {
                for dc in [-1, 1] {
                    let c = col + dc
                    guard c >= 0, c < 9 else { continue }
                    #expect(puzzle.solution[row * 9 + col] != puzzle.solution[(row + 1) * 9 + c])
                }
            }
        }
    }

    @Test func conflictDetectorFlagsKnightMoveDuplicates() {
        let puzzle = PuzzleGenerator().generateNow(
            variant: .antiKnight,
            difficulty: .easy,
            seed: 11,
        )
        // Find an empty cell and copy the digit from a knight's move away.
        let detector = ConflictDetector(puzzle: puzzle)
        var board = Board(puzzle: puzzle)
        outer: for cell in 0 ..< 81 where puzzle.givens[cell] == nil {
            let row = cell / 9
            let col = cell % 9
            for (dr, dc) in [(1, 2), (1, -2), (2, 1), (2, -1), (-1, 2), (-1, -2), (-2, 1), (-2, -1)] {
                let r = row + dr
                let c = col + dc
                guard r >= 0, r < 9, c >= 0, c < 9 else { continue }
                let peer = r * 9 + c
                if let given = puzzle.givens[peer] {
                    board[cell] = BoardCell(value: given, isGiven: false)
                    let conflicts = detector.conflicts(in: board)
                    #expect(conflicts.contains(cell))
                    #expect(conflicts.contains(peer))
                    break outer
                }
            }
        }
    }
}
