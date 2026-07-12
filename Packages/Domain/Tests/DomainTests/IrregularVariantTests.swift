import Testing
@testable import Domain
import Model

/// Jigsaw region generation, argyle clique constraints, and the asterisk
/// extra house.
@Suite
struct IrregularVariantTests {
    // MARK: - Region partitioner

    @Test func partitionYieldsConnectedEqualRegions() {
        var rng = Xoshiro256StarStar(seed: 0xDECAF_C0FFEE)
        let regions = RegionPartitioner.partition(size: 9, rng: &rng)
        #expect(regions.count == 81)
        for id in 0 ..< 9 {
            let members = regions.indices.filter { regions[$0] == id }
            #expect(members.count == 9)
            #expect(isConnected(members, size: 9))
        }
    }

    @Test func partitionIsDeterministicPerSeed() {
        var first = Xoshiro256StarStar(seed: 42)
        var second = Xoshiro256StarStar(seed: 42)
        var third = Xoshiro256StarStar(seed: 43)
        let a = RegionPartitioner.partition(size: 9, rng: &first)
        let b = RegionPartitioner.partition(size: 9, rng: &second)
        let c = RegionPartitioner.partition(size: 9, rng: &third)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func partitionActuallyLeavesTheStripLayout() {
        var rng = Xoshiro256StarStar(seed: 7)
        let regions = RegionPartitioner.partition(size: 9, rng: &rng)
        let strips = (0 ..< 81).map { $0 / 9 }
        #expect(regions != strips)
    }

    // MARK: - Jigsaw generation

    @Test func jigsawPuzzleCarriesItsRegionsAndIsDeterministic() throws {
        let generator = PuzzleGenerator()
        let puzzle = generator.generateNow(variant: .jigsaw, difficulty: .easy, seed: 99)
        let again = generator.generateNow(variant: .jigsaw, difficulty: .easy, seed: 99)
        #expect(puzzle == again)

        let boxes = try #require(puzzle.irregularBoxes)
        // The solution honors every irregular region.
        for id in 0 ..< 9 {
            let members = boxes.indices.filter { boxes[$0] == id }
            #expect(Set(members.map { puzzle.solution[$0] }).count == 9)
        }
        // The puzzle-aware topology renders those regions as boxes.
        let topology = TopologyFactory.topology(for: puzzle)
        #expect(topology.boxIndex == boxes)
    }

    // MARK: - Argyle

    @Test func argyleTopologyKeepsShortLinesOutOfHouses() {
        let topology = TopologyFactory.topology(for: .argyle)
        #expect(topology.cliques.count == 6)
        #expect(topology.diagonals == topology.cliques)
        #expect(topology.houses.count == 27)
        // Marked lines widen peers: the center cell sees all four diamond
        // edges' far ends through the context.
        let context = SolverContext(topology: topology)
        let corner = 0 // r0c0, on the main diagonal
        #expect(context.peers[corner].contains(80)) // r8c8 via the diagonal
    }

    @Test func argyleSolutionsRespectMarkedLines() {
        let puzzle = PuzzleGenerator().generateNow(variant: .argyle, difficulty: .easy, seed: 5)
        let topology = TopologyFactory.topology(for: .argyle)
        for line in topology.cliques {
            let values = line.map { puzzle.solution[$0] }
            #expect(Set(values).count == values.count, "repeat on argyle line \(line)")
        }
    }

    // MARK: - Asterisk

    @Test func asteriskStarIsAFullHouse() {
        let topology = TopologyFactory.topology(for: .asterisk)
        #expect(topology.windows.count == 1)
        let star = topology.windows[0]
        #expect(star.count == 9)
        #expect(topology.houses.contains(star))

        let puzzle = PuzzleGenerator().generateNow(variant: .asterisk, difficulty: .easy, seed: 5)
        #expect(Set(star.map { puzzle.solution[$0] }).count == 9)
    }

    // MARK: - Support

    private func isConnected(_ cells: [Int], size: Int) -> Bool {
        guard let start = cells.first else { return false }
        let set = Set(cells)
        var seen: Set<Int> = [start]
        var frontier = [start]
        while let cell = frontier.popLast() {
            let row = cell / size
            let col = cell % size
            var neighbors: [Int] = []
            if row > 0 { neighbors.append(cell - size) }
            if row < size - 1 { neighbors.append(cell + size) }
            if col > 0 { neighbors.append(cell - 1) }
            if col < size - 1 { neighbors.append(cell + 1) }
            for next in neighbors where set.contains(next) && seen.insert(next).inserted {
                frontier.append(next)
            }
        }
        return seen.count == cells.count
    }
}
