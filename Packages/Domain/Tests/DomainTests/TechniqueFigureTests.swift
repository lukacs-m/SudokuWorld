import Model
import Testing
@testable import Domain

/// The learning section's illustrated figures must be genuine instances of
/// their technique: replayed through the solver ladder, the engine's next
/// step has to be exactly the placement or eliminations the figure shows.
@Suite
struct TechniqueFigureTests {
    @Test func everyTechniqueHasExactlyOneFigure() {
        let covered = TechniqueFigure.all.map(\.technique)
        #expect(covered.count == Technique.allCases.count)
        #expect(Set(covered) == Set(Technique.allCases))
        for technique in Technique.allCases {
            #expect(TechniqueFigure.figure(for: technique).technique == technique)
        }
    }

    @Test(arguments: Technique.allCases)
    func figureMatchesTheEngineStep(technique: Technique) {
        let figure = TechniqueFigure.figure(for: technique)
        let topology = TopologyFactory.topology(for: figure.variant)
        let context = SolverContext(
            topology: topology,
            cages: figure.cages,
            relations: figure.relations,
            arrows: figure.arrows,
            outsideClues: figure.outsideClues,
        )
        var givens = [Int?](repeating: nil, count: topology.cellCount)
        for (cell, digit) in figure.givens {
            givens[cell] = digit
        }
        var grid = SolverGrid(context: context, givens: givens)
        #expect(!grid.isContradicted, "the givens contradict each other")

        for (cell, digits) in figure.candidates {
            for digit in digits {
                #expect(
                    grid.candidates[cell] & SolverContext.mask(for: digit) != 0,
                    "cell \(cell) shows candidate \(digit), which the givens rule out",
                )
            }
            for digit in 1 ... topology.size where !digits.contains(digit) {
                grid.eliminate(digit, at: cell)
            }
        }
        #expect(!grid.isContradicted)

        let step = TechniqueLadder.nextStep(in: grid)
        #expect(step?.technique == figure.technique)
        guard let step else { return }
        #expect(Set(step.focusCells) == Set(figure.focusCells))
        #expect(
            Set(step.eliminations.map { "\($0.cell):\($0.digit)" })
                == Set(figure.eliminations.map { "\($0.index):\($0.digit)" }),
        )
        #expect(step.placements.count == (figure.placement == nil ? 0 : 1))
        if let placement = figure.placement, let found = step.placements.first {
            #expect(found.cell == placement.index)
            #expect(found.digit == placement.digit)
        }
    }
}
