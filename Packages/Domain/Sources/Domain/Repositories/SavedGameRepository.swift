public import Model

/// Persistence for resumable in-flight games. At most one saved game exists
/// per context key ("main", "daily:<date>", "weekly:<week>").
public protocol SavedGameRepository: Sendable {
    func save(_ game: SavedGame) async throws
    func load(context: GameContext) async throws -> SavedGame?
    func delete(context: GameContext) async throws
}
