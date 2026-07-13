/// A summed run of cells: an arrow shaft totalling its circled cell, or (in
/// little killer) a diagonal totalling a fixed clue. Repeats along the run
/// are legal unless the cells share a house.
struct SumLine: Sendable, Hashable {
    enum Target: Sendable, Hashable {
        case cell(Int)
        case fixed(Int)
    }

    let cells: [Int]
    let target: Target
}
