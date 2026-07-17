import Model

/// Splits a square grid into `size` connected regions of `size` cells each,
/// for jigsaw puzzles. Starts from horizontal strips and morphs the borders
/// with size-preserving paired swaps, so every intermediate state is a valid
/// partition — the walk cannot fail, only stay closer to strips.
/// Deterministic for a given rng state.
enum RegionPartitioner {
    static func partition(
        size: Int,
        mutations: Int = 240,
        rng: inout Xoshiro256StarStar,
    ) -> [Int] {
        let cellCount = size * size
        var region = (0 ..< cellCount).map { $0 / size }

        var applied = 0
        var attempts = 0
        while applied < mutations, attempts < mutations * 20 {
            attempts += 1

            // A random border cell x, and the neighboring region it touches.
            let x = Int(rng.next(upperBound: UInt64(cellCount)))
            let a = region[x]
            guard let neighbor = neighbors(of: x, size: size)
                .shuffled(using: &rng)
                .first(where: { region[$0] != a })
            else { continue }
            let b = region[neighbor]

            // A counterpart y in b that borders a, so sizes stay equal.
            let candidates = (0 ..< cellCount)
                .filter { cell in
                    cell != x && region[cell] == b
                        && neighbors(of: cell, size: size).contains { region[$0] == a }
                }
                .shuffled(using: &rng)

            for y in candidates {
                region[x] = b
                region[y] = a
                if isConnected(region: region, id: a, size: size),
                   isConnected(region: region, id: b, size: size)
                {
                    applied += 1
                    break
                }
                region[x] = a
                region[y] = b
            }
        }
        return region
    }

    private static func neighbors(of cell: Int, size: Int) -> [Int] {
        let row = cell / size
        let col = cell % size
        var result: [Int] = []
        if row > 0 {
            result.append(cell - size)
        }
        if row < size - 1 {
            result.append(cell + size)
        }
        if col > 0 {
            result.append(cell - 1)
        }
        if col < size - 1 {
            result.append(cell + 1)
        }
        return result
    }

    private static func isConnected(region: [Int], id: Int, size: Int) -> Bool {
        let members = region.indices.filter { region[$0] == id }
        guard let start = members.first else { return false }
        var seen: Set<Int> = [start]
        var frontier = [start]
        while let cell = frontier.popLast() {
            for next in neighbors(of: cell, size: size)
                where region[next] == id && seen.insert(next).inserted
            {
                frontier.append(next)
            }
        }
        return seen.count == members.count
    }
}
