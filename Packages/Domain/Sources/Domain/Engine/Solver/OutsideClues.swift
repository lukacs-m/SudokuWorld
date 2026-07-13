import Model

/// Resolves outside clues to ordered cell lines (reading from the clue's
/// edge inward) and verifies completed lines. Shared by the solver, the
/// conflict detector, and the generator.
enum OutsideClues {
    /// The cells a clue reads, starting at its edge. Little-killer diagonals
    /// use one fixed direction per side: top ↘, trailing ↙, bottom ↖,
    /// leading ↗.
    static func line(for clue: OutsideClue, topology: GridTopology) -> [Int] {
        let size = topology.size
        switch clue.kind {
        case .sandwichSum, .skyscraperCount:
            return switch clue.side {
            case .leading: (0 ..< size).compactMap {
                    topology.index(row: clue.offset, col: $0)
                }
            case .trailing: (0 ..< size).compactMap {
                    topology.index(row: clue.offset, col: size - 1 - $0)
                }
            case .top: (0 ..< size).compactMap {
                    topology.index(row: $0, col: clue.offset)
                }
            case .bottom: (0 ..< size).compactMap {
                    topology.index(row: size - 1 - $0, col: clue.offset)
                }
            }
        case .diagonalSum:
            let (start, step): ((Int, Int), (Int, Int)) = switch clue.side {
            case .top: ((0, clue.offset), (1, 1))
            case .trailing: ((clue.offset, size - 1), (1, -1))
            case .bottom: ((size - 1, clue.offset), (-1, -1))
            case .leading: ((clue.offset, 0), (-1, 1))
            }
            var cells: [Int] = []
            var row = start.0
            var col = start.1
            while row >= 0, row < size, col >= 0, col < size {
                if let index = topology.index(row: row, col: col) {
                    cells.append(index)
                }
                row += step.0
                col += step.1
            }
            return cells
        }
    }

    /// Whether a fully assigned line satisfies its clue.
    static func satisfied(clue: OutsideClue, lineValues values: [Int], size: Int) -> Bool {
        switch clue.kind {
        case .diagonalSum:
            return values.reduce(0, +) == clue.value
        case .skyscraperCount:
            var tallest = 0
            var visible = 0
            for value in values where value > tallest {
                tallest = value
                visible += 1
            }
            return visible == clue.value
        case .sandwichSum:
            guard let low = values.firstIndex(of: 1),
                  let high = values.firstIndex(of: size) else { return false }
            let inner = values[(min(low, high) + 1) ..< max(low, high)]
            return inner.reduce(0, +) == clue.value
        }
    }

    /// Derives every clue of a kind from a finished solution.
    static func derive(
        kind: OutsideClue.Kind,
        clues: [(side: OutsideClue.Side, offset: Int)],
        topology: GridTopology,
        solution: [Int],
    ) -> [OutsideClue] {
        clues.compactMap { side, offset in
            let probe = OutsideClue(kind: kind, side: side, offset: offset, value: 0)
            let cells = line(for: probe, topology: topology)
            guard cells.count >= 2 else { return nil }
            let values = cells.map { solution[$0] }
            let value: Int = switch kind {
            case .diagonalSum:
                values.reduce(0, +)
            case .skyscraperCount:
                values.reduce(into: (tallest: 0, visible: 0)) { state, value in
                    if value > state.tallest {
                        state.tallest = value
                        state.visible += 1
                    }
                }.visible
            case .sandwichSum:
                {
                    guard let low = values.firstIndex(of: 1),
                          let high = values.firstIndex(of: topology.size) else { return 0 }
                    return values[(min(low, high) + 1) ..< max(low, high)].reduce(0, +)
                }()
            }
            return OutsideClue(kind: kind, side: side, offset: offset, value: value)
        }
    }
}
