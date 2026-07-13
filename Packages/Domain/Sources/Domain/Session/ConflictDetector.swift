public import Model

/// Detects rule violations on a live board: duplicate digits sharing a house
/// or cage, parity-mark violations, and completed cages with a wrong sum.
/// Built once per puzzle; peer lists come from the same solver context the
/// engine uses, so detection stays consistent across every variant.
public struct ConflictDetector: Equatable, Sendable {
    private let puzzle: PuzzleDefinition
    let peers: [[Int]]
    private let relationEdges: [RelationEdge]

    public init(puzzle: PuzzleDefinition) {
        self.puzzle = puzzle
        let context = SolverContext(
            topology: TopologyFactory.topology(for: puzzle),
            cages: puzzle.cages,
            parities: puzzle.parities,
            relations: puzzle.relations,
            thermometers: puzzle.thermometers,
            arrows: puzzle.arrows,
        )
        peers = context.peers
        relationEdges = context.relationEdges
    }

    public static func == (lhs: ConflictDetector, rhs: ConflictDetector) -> Bool {
        lhs.puzzle.id == rhs.puzzle.id
    }

    /// Cell indices currently involved in a visible rule violation.
    public func conflicts(in board: Board) -> Set<Int> {
        var conflicted = Set<Int>()

        for index in 0 ..< board.count {
            guard let value = board[index].value else { continue }
            for peer in peers[index] where board[peer].value == value {
                conflicted.insert(index)
                conflicted.insert(peer)
            }
            if let parity = puzzle.parities[index], !parity.accepts(value) {
                conflicted.insert(index)
            }
        }

        for cage in puzzle.cages {
            let values = cage.cells.compactMap { board[$0].value }
            guard values.count == cage.cells.count else { continue }
            if values.reduce(0, +) != cage.sum {
                conflicted.formUnion(cage.cells)
            }
        }

        // Relation marks (and their negative convention) violated by two
        // filled endpoints. Thermometers arrive here as greater-than chains.
        for edge in relationEdges {
            guard let aValue = board[edge.a].value,
                  let bValue = board[edge.b].value else { continue }
            if !edge.satisfied(a: aValue, b: bValue) {
                conflicted.insert(edge.a)
                conflicted.insert(edge.b)
            }
        }

        // Completed arrows whose shaft misses the circled total.
        for arrow in puzzle.arrows {
            guard let circle = board[arrow.circle].value else { continue }
            let shaft = arrow.shaft.compactMap { board[$0].value }
            guard shaft.count == arrow.shaft.count else { continue }
            if shaft.reduce(0, +) != circle {
                conflicted.insert(arrow.circle)
                conflicted.formUnion(arrow.shaft)
            }
        }
        return conflicted
    }

    /// True when every cell matches the stored solution.
    public func isSolved(_ board: Board) -> Bool {
        (0 ..< board.count).allSatisfy { board[$0].value == puzzle.solution[$0] }
    }
}
