import Model

/// Derives a variant's visible relation marks from a finished solution.
/// Marks are exhaustive (every qualifying adjacent pair is marked), which is
/// what gives the negative convention its meaning.
enum RelationMarks {
    static func derive(
        variant: SudokuVariant,
        topology: GridTopology,
        solution: [Int],
        rng: inout Xoshiro256StarStar,
    ) -> [RelationClue] {
        switch variant {
        case .kropki:
            kropki(topology: topology, solution: solution, rng: &rng)

        case .xv:
            RelationExpansion.orthogonalPairs(in: topology).compactMap { a, b in
                switch solution[a] + solution[b] {
                case 10: RelationClue(a: a, b: b, kind: .xSum)
                case 5: RelationClue(a: a, b: b, kind: .vSum)
                default: nil
                }
            }

        case .consecutive:
            RelationExpansion.orthogonalPairs(in: topology).compactMap { a, b in
                abs(solution[a] - solution[b]) == 1
                    ? RelationClue(a: a, b: b, kind: .consecutive)
                    : nil
            }

        case .greaterThan:
            // Futoshiki-style: an inequality on every adjacent pair that
            // shares a box, oriented from the larger value.
            RelationExpansion.orthogonalPairs(in: topology).compactMap { a, b in
                guard topology.boxIndex[a] == topology.boxIndex[b] else { return nil }
                return solution[a] > solution[b]
                    ? RelationClue(a: a, b: b, kind: .greaterThan)
                    : RelationClue(a: b, b: a, kind: .greaterThan)
            }

        case .miracle:
            // Pure miracle: no visible marks at all — the rules are global.
            []

        default:
            []
        }
    }

    /// Kropki: a dot on every consecutive or double pair. A pair that is
    /// both (1|2) draws one of the two dots, chosen by seed.
    private static func kropki(
        topology: GridTopology,
        solution: [Int],
        rng: inout Xoshiro256StarStar,
    ) -> [RelationClue] {
        RelationExpansion.orthogonalPairs(in: topology).compactMap { a, b in
            let low = min(solution[a], solution[b])
            let high = max(solution[a], solution[b])
            let isConsecutive = high - low == 1
            let isRatio = high == 2 * low
            switch (isConsecutive, isRatio) {
            case (true, true):
                return RelationClue(
                    a: a,
                    b: b,
                    kind: rng.next().isMultiple(of: 2) ? .whiteDot : .blackDot,
                )

            case (true, false):
                return RelationClue(a: a, b: b, kind: .whiteDot)

            case (false, true):
                return RelationClue(a: a, b: b, kind: .blackDot)

            case (false, false):
                return nil
            }
        }
    }
}
