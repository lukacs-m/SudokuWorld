import Model

/// A pairwise constraint in solver form. Positive edges come straight from
/// visible marks; negative edges are the *absence* of a mark, which in
/// kropki/XV/consecutive convention is itself a rule ("no dot" means "not
/// consecutive and not in ratio") — and what makes sparse-given boards
/// solvable at all.
struct RelationEdge: Sendable, Hashable {
    enum Constraint: Sendable, Hashable {
        /// value(a) > value(b).
        case greater
        /// |a − b| == 1.
        case consecutive
        case notConsecutive
        /// One value is exactly double the other.
        case ratio
        case notRatio
        /// a + b equals the sum.
        case sum(Int)
        case notSum(Int)
    }

    let a: Int
    let b: Int
    let constraint: Constraint

    /// Digits still possible for one endpoint, given the other endpoint's
    /// candidates. `forA` computes the mask for `a` from `b`'s candidates.
    func allowedMask(forA: Bool, partnerCandidates: DigitMask, size: Int) -> DigitMask {
        var allowed: DigitMask = 0
        for digit in 1 ... size {
            let digitMask = SolverContext.mask(for: digit)
            for partner in 1 ... size
                where partnerCandidates & SolverContext.mask(for: partner) != 0
            {
                let aValue = forA ? digit : partner
                let bValue = forA ? partner : digit
                if satisfied(a: aValue, b: bValue) {
                    allowed |= digitMask
                    break
                }
            }
        }
        return allowed
    }

    func satisfied(a aValue: Int, b bValue: Int) -> Bool {
        switch constraint {
        case .greater: aValue > bValue
        case .consecutive: abs(aValue - bValue) == 1
        case .notConsecutive: abs(aValue - bValue) != 1
        case .ratio: aValue == 2 * bValue || bValue == 2 * aValue
        case .notRatio: aValue != 2 * bValue && bValue != 2 * aValue
        case let .sum(total): aValue + bValue == total
        case let .notSum(total): aValue + bValue != total
        }
    }
}

/// Expands a puzzle's visible marks plus its variant's negative convention
/// into the full edge list the solver enforces.
enum RelationExpansion {
    static func edges(
        variant: SudokuVariant,
        relations: [RelationClue],
        topology: GridTopology,
        includeNegatives: Bool = true,
    ) -> [RelationEdge] {
        var edges = relations.map(markEdge)
        if includeNegatives {
            edges += negativeEdges(variant: variant, relations: relations, topology: topology)
        }
        return edges
    }

    private static func markEdge(for clue: RelationClue) -> RelationEdge {
        switch clue.kind {
        case .greaterThan: RelationEdge(a: clue.a, b: clue.b, constraint: .greater)

        case .whiteDot, .consecutive:
            RelationEdge(a: clue.a, b: clue.b, constraint: .consecutive)

        case .blackDot: RelationEdge(a: clue.a, b: clue.b, constraint: .ratio)

        case .xSum: RelationEdge(a: clue.a, b: clue.b, constraint: .sum(10))

        case .vSum: RelationEdge(a: clue.a, b: clue.b, constraint: .sum(5))
        }
    }

    /// The negative convention: every orthogonal pair NOT covered by a mark
    /// carries the complementary constraints.
    private static func negativeEdges(
        variant: SudokuVariant,
        relations: [RelationClue],
        topology: GridTopology,
    ) -> [RelationEdge] {
        let negatives: [RelationEdge.Constraint] = switch variant {
        case .kropki: [.notConsecutive, .notRatio]
        case .xv: [.notSum(10), .notSum(5)]
        case .consecutive, .miracle: [.notConsecutive]
        default: []
        }
        guard !negatives.isEmpty else { return [] }

        var marked = Set<[Int]>()
        for clue in relations {
            marked.insert([min(clue.a, clue.b), max(clue.a, clue.b)])
        }
        var edges: [RelationEdge] = []
        for (a, b) in orthogonalPairs(in: topology)
            where !marked.contains([min(a, b), max(a, b)])
        {
            for constraint in negatives {
                edges.append(RelationEdge(a: a, b: b, constraint: constraint))
            }
        }
        return edges
    }

    /// All orthogonally adjacent active cell pairs, each once.
    static func orthogonalPairs(in topology: GridTopology) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        for index in 0 ..< topology.cellCount {
            let position = topology.position(of: index)
            if let right = topology.index(row: position.row, col: position.col + 1) {
                pairs.append((index, right))
            }
            if let below = topology.index(row: position.row + 1, col: position.col) {
                pairs.append((index, below))
            }
        }
        return pairs
    }
}
