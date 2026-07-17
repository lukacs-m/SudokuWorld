import Foundation
import Testing
@testable import Model

/// Saved games embed `PuzzleDefinition` as a JSON blob, so every payload
/// field added after 1.0 must decode from JSON that predates it.
@Suite
struct PuzzleDefinitionCodableTests {
    /// A faithful pre-`irregularBoxes` payload (trimmed to a 4-cell board —
    /// the decoder doesn't validate dimensions).
    private let legacyJSON = """
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "variant": "classic",
      "requestedDifficulty": "easy",
      "gradedDifficulty": "easy",
      "seed": 42,
      "givens": [1, null, null, 2],
      "solution": [1, 2, 1, 2],
      "cages": [],
      "parities": {}
    }
    """

    @Test func legacyPayloadsDecode() throws {
        let puzzle = try JSONDecoder().decode(
            PuzzleDefinition.self,
            from: Data(legacyJSON.utf8),
        )
        #expect(puzzle.variant == .classic)
        #expect(puzzle.irregularBoxes == nil)
        #expect(puzzle.givens.count == 4)
    }

    @Test func roundTripKeepsNewFields() throws {
        let puzzle = PuzzleDefinition(
            id: UUID(),
            variant: .jigsaw,
            requestedDifficulty: .easy,
            gradedDifficulty: .easy,
            seed: 1,
            givens: [nil, 1],
            solution: [2, 1],
            irregularBoxes: [0, 0],
        )
        let data = try JSONEncoder().encode(puzzle)
        let decoded = try JSONDecoder().decode(PuzzleDefinition.self, from: data)
        #expect(decoded == puzzle)
        #expect(decoded.irregularBoxes == [0, 0])
    }
}
