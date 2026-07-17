import Model

/// Seeds thermometer paths and arrow clues onto a finished solution. Lines
/// never share cells, so every mark reads cleanly on the board.
enum LinePlacer {
    /// Thermometers: strictly increasing walks over the 8-neighborhood,
    /// bulb first. Easier grades get more (and thus more information).
    static func thermometers(
        topology: GridTopology,
        solution: [Int],
        difficulty: Difficulty,
        rng: inout Xoshiro256StarStar,
    ) -> [[Int]] {
        let targetCount = switch difficulty {
        case .beginner: 9
        case .easy: 8
        case .medium: 7
        case .hard: 6
        case .expert, .master: 5
        }
        var used = Set<Int>()
        var paths: [[Int]] = []
        var attempts = 0
        while paths.count < targetCount, attempts < 400 {
            attempts += 1
            let start = Int(rng.next(upperBound: UInt64(topology.cellCount)))
            guard !used.contains(start), solution[start] <= 5 else { continue }
            var path = [start]
            var current = start
            while path.count < 7 {
                let next = neighbors(of: current, topology: topology)
                    .filter { !used.contains($0) && !path.contains($0) }
                    .filter { solution[$0] > solution[current] }
                    .shuffled(using: &rng)
                    .first
                guard let next else { break }
                path.append(next)
                current = next
            }
            guard path.count >= 3 else { continue }
            paths.append(path)
            used.formUnion(path)
        }
        return paths
    }

    /// Arrows: a circled cell plus an adjacent walk whose digits sum to it.
    static func arrows(
        topology: GridTopology,
        solution: [Int],
        difficulty: Difficulty,
        rng: inout Xoshiro256StarStar,
    ) -> [Arrow] {
        let targetCount = switch difficulty {
        case .beginner: 8
        case .easy: 7
        case .medium: 6
        case .hard: 5
        case .expert, .master: 4
        }
        var used = Set<Int>()
        var arrows: [Arrow] = []
        var attempts = 0
        while arrows.count < targetCount, attempts < 400 {
            attempts += 1
            let circle = Int(rng.next(upperBound: UInt64(topology.cellCount)))
            guard !used.contains(circle), solution[circle] >= 4 else { continue }
            let target = solution[circle]

            var shaft: [Int] = []
            var sum = 0
            var current = circle
            while sum < target {
                let next = neighbors(of: current, topology: topology)
                    .filter { !used.contains($0) && !shaft.contains($0) && $0 != circle }
                    .filter { sum + solution[$0] <= target }
                    .shuffled(using: &rng)
                    .first
                guard let next else { break }
                shaft.append(next)
                sum += solution[next]
                current = next
            }
            guard sum == target, shaft.count >= 2 else { continue }
            arrows.append(Arrow(circle: circle, shaft: shaft))
            used.insert(circle)
            used.formUnion(shaft)
        }
        return arrows
    }

    private static func neighbors(of cell: Int, topology: GridTopology) -> [Int] {
        let position = topology.position(of: cell)
        var result: [Int] = []
        for dr in -1 ... 1 {
            for dc in -1 ... 1 where dr != 0 || dc != 0 {
                if let neighbor = topology.index(
                    row: position.row + dr,
                    col: position.col + dc,
                ) {
                    result.append(neighbor)
                }
            }
        }
        return result
    }
}
