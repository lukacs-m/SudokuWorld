import Testing
@testable import Domain
import Model

@Suite
struct TopologyTests {
    @Test(arguments: [
        (SudokuVariant.classic, 81, 27),
        (SudokuVariant.mini6, 36, 18),
        (SudokuVariant.killer, 81, 27),
        (SudokuVariant.diagonal, 81, 29),
        (SudokuVariant.windoku, 81, 31),
        (SudokuVariant.evenOdd, 81, 27),
        (SudokuVariant.samurai, 369, 131),
    ])
    func cellAndHouseCounts(variant: SudokuVariant, cellCount: Int, houseCount: Int) {
        let topology = TopologyFactory.topology(for: variant)
        #expect(topology.cellCount == cellCount)
        #expect(topology.houses.count == houseCount)
        #expect(topology.houseKinds.count == houseCount)
        #expect(topology.boxIndex.count == cellCount)
    }

    @Test(arguments: SudokuVariant.allCases)
    func housesAreValidUnits(variant: SudokuVariant) {
        let topology = TopologyFactory.topology(for: variant)
        for house in topology.houses {
            #expect(house.count == topology.size)
            #expect(Set(house).count == topology.size)
            for cell in house {
                #expect(cell >= 0 && cell < topology.cellCount)
            }
        }
    }

    @Test(arguments: SudokuVariant.allCases)
    func indexLookupRoundtrips(variant: SudokuVariant) {
        let topology = TopologyFactory.topology(for: variant)
        for (index, position) in topology.cells.enumerated() {
            #expect(topology.index(row: position.row, col: position.col) == index)
        }
    }

    @Test func samuraiHasFourSharedBoxes() {
        let topology = TopologyFactory.topology(for: .samurai)
        // 5 grids × 9 boxes − 4 shared = 41 box houses.
        let boxHouses = topology.houseKinds.count(where: { $0 == .box })
        #expect(boxHouses == 41)
        // Corners of the 21×21 bounding box are inactive.
        #expect(topology.index(row: 0, col: 9) == nil)
        #expect(topology.index(row: 10, col: 0) == nil)
        #expect(topology.index(row: 10, col: 10) != nil)
    }

    @Test func windokuWindowsAreHouses() {
        let topology = TopologyFactory.topology(for: .windoku)
        #expect(topology.windows.count == 4)
        for window in topology.windows {
            #expect(window.count == 9)
            #expect(topology.houses.contains(window))
        }
    }

    @Test func diagonalTopologyExposesDiagonals() {
        let topology = TopologyFactory.topology(for: .diagonal)
        #expect(topology.diagonals.count == 2)
        let main = topology.diagonals[0]
        #expect(main.first == topology.index(row: 0, col: 0))
        #expect(main.last == topology.index(row: 8, col: 8))
    }
}
