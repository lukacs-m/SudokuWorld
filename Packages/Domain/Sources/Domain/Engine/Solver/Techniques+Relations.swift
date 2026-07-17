import Model

extension Techniques {
    /// Relation-mark analysis: an endpoint of a dot/inequality/bar edge (or
    /// of an expanded negative edge) keeps only digits with a compatible
    /// partner candidate. Mirrors `SolverGrid.propagateRelations` one step
    /// at a time so hints can spotlight the pair.
    static func relationAnalysis(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        guard !context.relationEdges.isEmpty else { return nil }

        for edge in context.relationEdges {
            for forA in [true, false] {
                let cell = forA ? edge.a : edge.b
                let partner = forA ? edge.b : edge.a
                guard grid.values[cell] == 0 else { continue }
                let partnerMask = grid.values[partner] == 0
                    ? grid.candidates[partner]
                    : SolverContext.mask(for: grid.values[partner])
                let allowed = edge.allowedMask(
                    forA: forA,
                    partnerCandidates: partnerMask,
                    size: context.size,
                )
                let removed = grid.candidates[cell] & ~allowed
                guard removed != 0 else { continue }
                return SolveStep(
                    technique: .relationAnalysis,
                    eliminations: context.digits(in: removed).map {
                        (cell: cell, digit: $0)
                    },
                    focusCells: [edge.a, edge.b],
                    focusDigits: context.digits(in: removed),
                )
            }
        }
        return nil
    }
}
