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
    /// Jigsaw region id per cell; nil for variants with regular boxes.
    /// Optional so saves from before this field decode unchanged.
    public let irregularBoxes: [Int]?
    /// Pairwise marks (kropki dots, XV letters, inequalities, bars); empty
    /// for variants without relation clues.
    public let relations: [RelationClue]

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
        irregularBoxes: [Int]? = nil,
        relations: [RelationClue] = [],
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
        self.irregularBoxes = irregularBoxes
        self.relations = relations
    }

    /// Custom decoding so payload fields added after 1.0 fall back to empty
    /// when a stored save predates them — synthesized decoding would throw
    /// on the missing key. Encoding stays synthesized. Every future payload
    /// field needs one `decodeIfPresent` line here.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        variant = try container.decode(SudokuVariant.self, forKey: .variant)
        requestedDifficulty = try container.decode(
            Difficulty.self,
            forKey: .requestedDifficulty,
        )
        gradedDifficulty = try container.decode(Difficulty.self, forKey: .gradedDifficulty)
        seed = try container.decode(UInt64.self, forKey: .seed)
        givens = try container.decode([Int?].self, forKey: .givens)
        solution = try container.decode([Int].self, forKey: .solution)
        cages = try container.decodeIfPresent([Cage].self, forKey: .cages) ?? []
        parities = try container.decodeIfPresent(
            [Int: CellParity].self,
            forKey: .parities,
        ) ?? [:]
        irregularBoxes = try container.decodeIfPresent([Int].self, forKey: .irregularBoxes)
        relations = try container.decodeIfPresent(
            [RelationClue].self,
            forKey: .relations,
        ) ?? []
    }
}
