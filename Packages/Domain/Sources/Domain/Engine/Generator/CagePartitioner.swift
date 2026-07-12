import Model

/// Partitions a solved grid into killer cages: orthogonally connected cells
/// with distinct digits, sums taken from the solution, and sizes biased by
/// the target difficulty (small forgiving cages early, long cages for master).
enum CagePartitioner {
    static func partition(
        topology: GridTopology,
        solution: [Int],
        difficulty: Difficulty,
        rng: inout Xoshiro256StarStar,
    ) -> [Cage] {
        var assigned = [Bool](repeating: false, count: topology.cellCount)
        var cages: [Cage] = []

        let order = Array(0 ..< topology.cellCount).shuffled(using: &rng)
        for start in order where !assigned[start] {
            let targetSize = sampleCageSize(for: difficulty, rng: &rng)
            var cageCells = [start]
            var usedDigits: Set<Int> = [solution[start]]
            assigned[start] = true

            while cageCells.count < targetSize {
                var frontier = Set<Int>()
                for cell in cageCells {
                    for neighbor in orthogonalNeighbors(of: cell, in: topology)
                        where !assigned[neighbor] && !usedDigits.contains(solution[neighbor])
                    {
                        frontier.insert(neighbor)
                    }
                }
                guard !frontier.isEmpty else { break }
                let choices = frontier.sorted()
                let next = choices[Int.random(in: 0 ..< choices.count, using: &rng)]
                cageCells.append(next)
                usedDigits.insert(solution[next])
                assigned[next] = true
            }

            let sum = cageCells.reduce(0) { $0 + solution[$1] }
            cages.append(Cage(cells: cageCells.sorted(), sum: sum))
        }
        return cages
    }

    private static func orthogonalNeighbors(of cell: Int, in topology: GridTopology) -> [Int] {
        let position = topology.position(of: cell)
        var neighbors: [Int] = []
        for (deltaRow, deltaCol) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            if let neighbor = topology.index(
                row: position.row + deltaRow,
                col: position.col + deltaCol,
            ) {
                neighbors.append(neighbor)
            }
        }
        return neighbors
    }

    private static func sampleCageSize(
        for difficulty: Difficulty,
        rng: inout Xoshiro256StarStar,
    ) -> Int {
        let distribution: [Int] = switch difficulty {
        case .beginner: [1, 2, 2, 3]
        case .easy: [2, 2, 3, 3]
        case .medium: [2, 3, 3, 4]
        case .hard: [2, 3, 4, 4]
        case .expert: [3, 4, 4, 5]
        case .master: [3, 4, 5, 5]
        }
        return distribution[Int.random(in: 0 ..< distribution.count, using: &rng)]
    }
}
