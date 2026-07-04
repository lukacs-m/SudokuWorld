public import Foundation

/// A fully generated puzzle: immutable input to a game session. Codable so it
/// persists as-is with a saved game.
public struct PuzzleDefinition: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let variant: SudokuVariant
    /// What the player asked for.
    public let requestedDifficulty: Difficulty
    /// What the generated puzzle actually grades at. Usually equal to
    /// `requestedDifficulty`; may be the nearest achievable grade when the
    /// generator exhausts its attempt budget. The fallback is deterministic,
    /// so event puzzles stay identical for every player.
    public let gradedDifficulty: Difficulty
    /// The seed that produced this puzzle — regenerating with it is repeatable.
    public let seed: UInt64
    /// One entry per cell index; non-nil values are fixed clues.
    public let givens: [Int?]
    /// The unique solution, one digit per cell index.
    public let solution: [Int]
    /// Killer cages; empty for other variants.
    public let cages: [Cage]
    /// Parity marks by cell index; empty for non Even-Odd variants.
    public let parities: [Int: CellParity]

    public init(
        id: UUID,
        variant: SudokuVariant,
        requestedDifficulty: Difficulty,
        gradedDifficulty: Difficulty,
        seed: UInt64,
        givens: [Int?],
        solution: [Int],
        cages: [Cage] = [],
        parities: [Int: CellParity] = [:],
    ) {
        self.id = id
        self.variant = variant
        self.requestedDifficulty = requestedDifficulty
        self.gradedDifficulty = gradedDifficulty
        self.seed = seed
        self.givens = givens
        self.solution = solution
        self.cages = cages
        self.parities = parities
    }
}
