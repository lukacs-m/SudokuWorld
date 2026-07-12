public import Model

/// Detects rule violations on a live board: duplicate digits sharing a house
/// or cage, parity-mark violations, and completed cages with a wrong sum.
/// Built once per puzzle; peer lists come from the same solver context the
/// engine uses, so detection stays consistent across every variant.
public struct ConflictDetector: Equatable, Sendable {
    private let puzzle: PuzzleDefinition
    let peers: [[Int]]

    public init(puzzle: PuzzleDefinition) {
        self.puzzle = puzzle
        let context = SolverContext(
            topology: TopologyFactory.topology(for: puzzle),
            cages: puzzle.cages,
            parities: puzzle.parities,
        )
        peers = context.peers
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
        return conflicted
    }

    /// True when every cell matches the stored solution.
    public func isSolved(_ board: Board) -> Bool {
        (0 ..< board.count).allSatisfy { board[$0].value == puzzle.solution[$0] }
    }
}
