import Testing
@testable import Domain
import Model

/// The cube: six full-house faces joined by bent-line cliques derived from
/// the net's edge table.
@Suite
struct CubeTopologyTests {
    private let topology = TopologyFactory.topology(for: .cube)

    @Test func fiftyFourCellsInSixBoxHouses() {
        #expect(topology.cellCount == 54)
        #expect(topology.houses.count == 6)
        #expect(topology.houseKinds.allSatisfy { $0 == .box })
        #expect(topology.rowCount == 9)
        #expect(topology.colCount == 12)
        #expect(topology.windows.isEmpty)
        #expect(topology.diagonals.isEmpty)
    }

    @Test func everyCellLiesInExactlyOneFace() {
        var membership = [Int](repeating: 0, count: topology.cellCount)
        for (face, house) in topology.houses.enumerated() {
            for cell in house {
                membership[cell] += 1
                #expect(topology.boxIndex[cell] == face)
                #expect(CubeNet.facePosition(of: cell).face.rawValue == face)
            }
        }
        #expect(membership.allSatisfy { $0 == 1 })
    }

    @Test func facesSitOnTheCrossNet() {
        for face in CubeNet.Face.allCases {
            for row in 0 ..< 3 {
                for col in 0 ..< 3 {
                    let index = CubeNet.index(face: face, row: row, col: col)
                    let net = topology.position(of: index)
                    #expect(topology.index(row: net.row, col: net.col) == index)
                    let back = CubeNet.facePosition(of: index)
                    #expect(back.face == face && back.row == row && back.col == col)
                }
            }
        }
        // The empty corners of the cross are inactive.
        #expect(topology.index(row: 0, col: 0) == nil)
        #expect(topology.index(row: 8, col: 11) == nil)
    }

    @Test func twelveEdgesEachJoinTwoDistinctFaceSides() {
        #expect(CubeNet.edges.count == 12)
        var sides = Set<String>()
        for edge in CubeNet.edges {
            #expect(edge.faceA != edge.faceB)
            sides.insert("\(edge.faceA)-\(edge.sideA)")
            sides.insert("\(edge.faceB)-\(edge.sideB)")
        }
        // Every face uses each of its four sides exactly once.
        #expect(sides.count == 24)
    }

    @Test func everyEdgeYieldsThreeCliquesCrossingInBothDirections() {
        #expect(topology.cliques.count == 36)
        for (offset, edge) in CubeNet.edges.enumerated() {
            for k in 0 ..< 3 {
                let clique = topology.cliques[offset * 3 + k]
                #expect(clique.count == 6)
                #expect(Set(clique).count == 6)
                let onA = clique.filter { CubeNet.facePosition(of: $0).face == edge.faceA }
                let onB = clique.filter { CubeNet.facePosition(of: $0).face == edge.faceB }
                #expect(onA.count == 3)
                #expect(onB.count == 3)
            }
        }
    }

    @Test func everyLineOfEveryFaceContinuesAtBothEnds() {
        // Each face row/column crosses two edges, so it belongs to exactly
        // two cliques; each cell (one row + one column) to four.
        var perCell = [Int](repeating: 0, count: topology.cellCount)
        for clique in topology.cliques {
            for cell in clique {
                perCell[cell] += 1
            }
        }
        #expect(perCell.allSatisfy { $0 == 4 })
    }

    @Test func bentLinesAreStraightOnTheNetWhereFacesTouch() {
        // Net-adjacent faces (unflipped, sharing a net line) continue rows
        // and columns as contiguous straight lines on the 2D net; the seven
        // folds do not. Left↔back is collinear on the net but wraps around.
        var contiguous = 0
        for clique in topology.cliques {
            let positions = clique.map(topology.position(of:))
            let adjacentOnNet = zip(positions, positions.dropFirst()).allSatisfy {
                abs($0.row - $1.row) + abs($0.col - $1.col) == 1
            }
            guard adjacentOnNet else { continue }
            contiguous += 1
            let rows = Set(positions.map(\.row))
            let cols = Set(positions.map(\.col))
            #expect(rows.count == 1 || cols.count == 1)
        }
        #expect(contiguous == 5 * 3)
    }

    @Test func generatedSolutionHonoursFacesAndBentLines() {
        let puzzle = PuzzleGenerator().generateNow(variant: .cube, difficulty: .easy, seed: 7)
        for face in topology.houses {
            #expect(Set(face.map { puzzle.solution[$0] }).count == 9)
        }
        for clique in topology.cliques {
            #expect(Set(clique.map { puzzle.solution[$0] }).count == 6)
        }
    }
}
