public import Model

/// The next logical step for the current board, with its explanation.
public protocol GetHintUseCase: Sendable {
    func callAsFunction(board: Board, puzzle: PuzzleDefinition) async -> Hint?
}

public struct GetHint: GetHintUseCase {
    private let engine = HintEngine()

    public init() {}

    public func callAsFunction(board: Board, puzzle: PuzzleDefinition) -> Hint? {
        engine.nextHint(board: board, puzzle: puzzle)
    }
}

/// Reveals a cell straight from the solution (the "just tell me" option).
public protocol RevealCellUseCase: Sendable {
    func callAsFunction(board: Board, puzzle: PuzzleDefinition, preferredCell: Int?) async -> Hint?
}

public struct RevealCell: RevealCellUseCase {
    private let engine = HintEngine()

    public init() {}

    public func callAsFunction(
        board: Board,
        puzzle: PuzzleDefinition,
        preferredCell: Int?,
    ) -> Hint? {
        engine.revealHint(preferredCell: preferredCell, board: board, puzzle: puzzle)
    }
}
