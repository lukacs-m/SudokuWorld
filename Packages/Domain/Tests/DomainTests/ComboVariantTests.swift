import Testing
@testable import Domain
import Model

/// Killer GT composition and the unfolded tredoku corner.
@Suite
struct ComboVariantTests {
    @Test func killerGTComposesCagesAndInequalities() {
        let puzzle = PuzzleGenerator().generateNow(variant: .killerGT, difficulty: .easy, seed: 15)
        #expect(!puzzle.cages.isEmpty)
        #expect(!puzzle.relations.isEmpty)

        var cageIndex = [Int](repeating: -1, count: 81)
        for (index, cage) in puzzle.cages.enumerated() {
            for cell in cage.cells {
                cageIndex[cell] = index
            }
        }
        for clue in puzzle.relations {
            #expect(clue.kind == .greaterThan)
            #expect(cageIndex[clue.a] == cageIndex[clue.b], "marks stay inside one cage")
            #expect(puzzle.solution[clue.a] > puzzle.solution[clue.b])
        }
    }

    @Test func tredokuFacesAndBentLinesHold() {
        let topology = TopologyFactory.topology(for: .tredoku)
        #expect(topology.cellCount == 27)
        #expect(topology.houses.count == 3)
        #expect(topology.cliques.count == 6)
        #expect(topology.cliques.allSatisfy { $0.count == 6 })

        let puzzle = PuzzleGenerator().generateNow(variant: .tredoku, difficulty: .easy, seed: 16)
        for face in topology.houses {
            #expect(Set(face.map { puzzle.solution[$0] }).count == 9)
        }
        for line in topology.cliques {
            let values = line.map { puzzle.solution[$0] }
            #expect(Set(values).count == values.count, "bent line repeats a digit")
        }
    }
}
