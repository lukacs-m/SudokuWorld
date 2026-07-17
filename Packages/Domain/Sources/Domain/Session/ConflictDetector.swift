public import Model

/// Detects rule violations on a live board: duplicate digits sharing a house
/// or cage, parity-mark violations, and completed cages with a wrong sum.
/// Built once per puzzle; peer lists come from the same solver context the
/// engine uses, so detection stays consistent across every variant.
public struct ConflictDetector: Equatable, Sendable {
    private let puzzle: PuzzleDefinition
    let peers: [[Int]]
    private let relationEdges: [RelationEdge]
    private let topology: GridTopology

    public init(puzzle: PuzzleDefinition) {
        self.puzzle = puzzle
        let context = SolverContext(
            topology: TopologyFactory.topology(for: puzzle),
            cages: puzzle.cages,
            parities: puzzle.parities,
            relations: puzzle.relations,
            thermometers: puzzle.thermometers,
            arrows: puzzle.arrows,
            outsideClues: puzzle.outsideClues,
        )
        peers = context.peers
        relationEdges = context.relationEdges
        topology = context.topology
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.puzzle.id == rhs.puzzle.id
    }

    /// Cell indices currently involved in a visible rule violation.
    public func conflicts(in board: Board) -> Set<Int> {
        var conflicted = Set<Int>()
        collectPeerAndParityConflicts(in: board, into: &conflicted)
        collectCageConflicts(in: board, into: &conflicted)
        collectRelationConflicts(in: board, into: &conflicted)
        collectLineConflicts(in: board, into: &conflicted)
        return conflicted
    }

    private func collectPeerAndParityConflicts(
        in board: Board,
        into conflicted: inout Set<Int>,
    ) {
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
    }

    private func collectCageConflicts(in board: Board, into conflicted: inout Set<Int>) {
        for cage in puzzle.cages {
            let values = cage.cells.compactMap { board[$0].value }
            guard values.count == cage.cells.count else { continue }
            if values.reduce(0, +) != cage.sum {
                conflicted.formUnion(cage.cells)
            }
        }
    }

    /// Relation marks (and their negative convention) violated by two
    /// filled endpoints. Thermometers arrive here as greater-than chains.
    private func collectRelationConflicts(in board: Board, into conflicted: inout Set<Int>) {
        for edge in relationEdges {
            guard let aValue = board[edge.a].value,
                  let bValue = board[edge.b].value else { continue }
            if !edge.satisfied(a: aValue, b: bValue) {
                conflicted.insert(edge.a)
                conflicted.insert(edge.b)
            }
        }
    }

    /// Completed arrows whose shaft misses the circled total, and completed
    /// outside-clue lines that miss their clue.
    private func collectLineConflicts(in board: Board, into conflicted: inout Set<Int>) {
        for arrow in puzzle.arrows {
            guard let circle = board[arrow.circle].value else { continue }
            let shaft = arrow.shaft.compactMap { board[$0].value }
            guard shaft.count == arrow.shaft.count else { continue }
            if shaft.reduce(0, +) != circle {
                conflicted.insert(arrow.circle)
                conflicted.formUnion(arrow.shaft)
            }
        }

        for clue in puzzle.outsideClues {
            let cells = OutsideClues.line(for: clue, topology: topology)
            let lineValues = cells.compactMap { board[$0].value }
            guard lineValues.count == cells.count else { continue }
            if !OutsideClues.satisfied(
                clue: clue,
                lineValues: lineValues,
                size: topology.size,
            ) {
                conflicted.formUnion(cells)
            }
        }
    }

    /// True when every cell matches the stored solution.
    public func isSolved(_ board: Board) -> Bool {
        (0 ..< board.count).allSatisfy { board[$0].value == puzzle.solution[$0] }
    }
}
