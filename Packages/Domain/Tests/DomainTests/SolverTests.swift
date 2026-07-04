import Testing
@testable import Domain
import Model

/// Parses "530070000…" row strings into givens (0 = empty).
func parseGivens(_ rows: [String]) -> [Int?] {
    rows.flatMap { row in
        row.map { character in
            let digit = Int(String(character)) ?? 0
            return digit == 0 ? nil : digit
        }
    }
}

func parseSolution(_ rows: [String]) -> [Int] {
    rows.flatMap { row in
        row.compactMap { Int(String($0)) }
    }
}

enum Fixtures {
    /// The well-known Wikipedia example puzzle.
    static let classicGivens = parseGivens([
        "530070000",
        "600195000",
        "098000060",
        "800060003",
        "400803001",
        "700020006",
        "060000280",
        "000419005",
        "000080079",
    ])

    static let classicSolution = parseSolution([
        "534678912",
        "672195348",
        "198342567",
        "859761423",
        "426853791",
        "713924856",
        "961537284",
        "287419635",
        "345286179",
    ])
}

@Suite
struct SolverTests {
    @Test func solvesKnownClassicPuzzle() {
        let topology = TopologyFactory.topology(for: .classic)
        let solver = Solver(topology: topology, givens: Fixtures.classicGivens)
        #expect(solver.solve() == Fixtures.classicSolution)
    }

    @Test func knownPuzzleIsUnique() {
        let topology = TopologyFactory.topology(for: .classic)
        let solver = Solver(topology: topology, givens: Fixtures.classicGivens)
        #expect(solver.solutionCount(limit: 2) == 1)
    }

    @Test func emptyGridIsAmbiguous() {
        let topology = TopologyFactory.topology(for: .classic)
        let solver = Solver(topology: topology, givens: [Int?](repeating: nil, count: 81))
        #expect(solver.solutionCount(limit: 2) == 2)
    }

    @Test func contradictoryGivensHaveNoSolution() {
        let topology = TopologyFactory.topology(for: .classic)
        var givens = [Int?](repeating: nil, count: 81)
        givens[0] = 5
        givens[1] = 5 // same row → illegal
        let solver = Solver(topology: topology, givens: givens)
        #expect(solver.solutionCount(limit: 2) == 0)
        #expect(solver.solve() == nil)
    }

    @Test func respectsParityConstraints() {
        let topology = TopologyFactory.topology(for: .evenOdd)
        // Solving the known grid with a parity mark contradicting its solution
        // must fail; a matching mark must still succeed.
        let solution = Fixtures.classicSolution
        let wrongParity: [Int: CellParity] = [0: solution[0].isMultiple(of: 2) ? .odd : .even]
        let failing = Solver(
            topology: topology,
            givens: Fixtures.classicGivens,
            parities: wrongParity,
        )
        #expect(failing.solutionCount(limit: 2) == 0)

        let rightParity: [Int: CellParity] = [0: solution[0].isMultiple(of: 2) ? .even : .odd]
        let succeeding = Solver(
            topology: topology,
            givens: Fixtures.classicGivens,
            parities: rightParity,
        )
        #expect(succeeding.solve() == solution)
    }

    @Test func respectsCageConstraints() {
        let topology = TopologyFactory.topology(for: .killer)
        let solution = Fixtures.classicSolution
        // A correct cage over the first two cells keeps the solution reachable.
        let goodCage = Cage(cells: [0, 1], sum: solution[0] + solution[1])
        let good = Solver(topology: topology, givens: Fixtures.classicGivens, cages: [goodCage])
        #expect(good.solve() == solution)

        // A wrong sum makes the puzzle unsolvable.
        let badCage = Cage(cells: [0, 1], sum: solution[0] + solution[1] + 1)
        let bad = Solver(topology: topology, givens: Fixtures.classicGivens, cages: [badCage])
        #expect(bad.solutionCount(limit: 2) == 0)
    }

    @Test func solvedHousesAreAllDifferent() {
        let topology = TopologyFactory.topology(for: .classic)
        let solver = Solver(topology: topology, givens: Fixtures.classicGivens)
        guard let solution = solver.solve() else {
            Issue.record("Expected a solution")
            return
        }
        for house in topology.houses {
            #expect(Set(house.map { solution[$0] }).count == topology.size)
        }
    }
}
