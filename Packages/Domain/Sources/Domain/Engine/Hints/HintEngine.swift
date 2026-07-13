public import Model

/// Turns the solver's next logical step into a player-facing hint, or reveals
/// a cell straight from the stored solution. Hints are computed from the
/// engine's own candidate analysis of the current values — the player's
/// pencil notes are never trusted.
public struct HintEngine: Sendable {
    public init() {}

    /// The next logical step for the current board. Wrong entries take
    /// priority: the first one found becomes a corrective reveal hint.
    /// Returns nil only when the board is already complete.
    public func nextHint(board: Board, puzzle: PuzzleDefinition) -> Hint? {
        let topology = TopologyFactory.topology(for: puzzle)

        for index in 0 ..< board.count {
            let cell = board[index]
            if let value = cell.value, !cell.isGiven, value != puzzle.solution[index] {
                let position = topology.position(of: index)
                return Hint(
                    kind: .reveal,
                    cells: [index],
                    placement: Hint.Placement(index: index, digit: puzzle.solution[index]),
                    explanationKey: "hint.mistake",
                    explanationArguments: [.row(position.row + 1), .column(position.col + 1)],
                )
            }
        }
        guard !board.isFilled else { return nil }

        let context = SolverContext(
            topology: topology,
            cages: puzzle.cages,
            parities: puzzle.parities,
        )
        let grid = SolverGrid(context: context, givens: board.values)
        if !grid.isContradicted, let step = TechniqueLadder.nextStep(in: grid) {
            return hint(from: step, topology: topology)
        }
        // Logic is stuck from this position (rare) — fall back to a reveal.
        return revealHint(preferredCell: nil, board: board, puzzle: puzzle)
    }

    /// Reveals the solution digit of a cell: the preferred cell when it is
    /// empty or wrong, otherwise the first such cell on the board.
    public func revealHint(preferredCell: Int?, board: Board, puzzle: PuzzleDefinition) -> Hint? {
        func isRevealable(_ index: Int) -> Bool {
            let cell = board[index]
            guard !cell.isGiven else { return false }
            return cell.value != puzzle.solution[index]
        }

        let target: Int? = if let preferredCell, preferredCell < board.count,
                              isRevealable(preferredCell)
        {
            preferredCell
        } else {
            (0 ..< board.count).first(where: isRevealable)
        }
        guard let index = target else { return nil }

        let digit = puzzle.solution[index]
        let position = TopologyFactory.topology(for: puzzle).position(of: index)
        return Hint(
            kind: .reveal,
            cells: [index],
            placement: Hint.Placement(index: index, digit: digit),
            explanationKey: "hint.reveal",
            explanationArguments: [
                .digit(digit), .row(position.row + 1), .column(position.col + 1),
            ],
        )
    }

    private func hint(from step: SolveStep, topology: GridTopology) -> Hint {
        let args: [Hint.Argument]
        switch step.technique {
        case .nakedSingle, .hiddenSingle:
            if let placement = step.placements.first {
                let position = topology.position(of: placement.cell)
                args = [
                    .digit(placement.digit),
                    .row(position.row + 1),
                    .column(position.col + 1),
                ]
            } else {
                args = []
            }
        default:
            args = [.digits(step.focusDigits)]
        }

        return Hint(
            kind: .logical(step.technique),
            cells: step.focusCells,
            placement: step.placements.first.map {
                Hint.Placement(index: $0.cell, digit: $0.digit)
            },
            eliminations: step.eliminations.map {
                Hint.Elimination(index: $0.cell, digit: $0.digit)
            },
            explanationKey: "hint.technique.\(step.technique.rawValue)",
            explanationArguments: args,
        )
    }
}
