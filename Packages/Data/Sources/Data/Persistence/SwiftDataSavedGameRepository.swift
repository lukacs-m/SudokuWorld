public import Domain
import Foundation
public import Model
import SwiftData

/// SwiftData-backed saved games. A hand-rolled actor (not `@ModelActor` —
/// its generated members are public and would force `public import
/// SwiftData`); the context lives and dies inside the actor, and only
/// `SavedGame` values cross the boundary.
public actor SwiftDataSavedGameRepository: SavedGameRepository {
    private let container: ModelContainer
    private lazy var context = ModelContext(container)

    /// Production instance on the shared on-disk container.
    public init() {
        container = ModelContainerProvider.shared
    }

    /// Test hook: any container, typically in-memory.
    init(container: ModelContainer) {
        self.container = container
    }

    public func save(_ game: SavedGame) throws {
        let key = game.context.contextKey
        let payload = try PersistenceMappers.encode(game)
        if let existing = try fetchEntity(contextKey: key) {
            existing.payload = payload
            existing.updatedAt = game.updatedAt
        } else {
            context.insert(SavedGameEntity(
                contextKey: key,
                payload: payload,
                updatedAt: game.updatedAt,
            ))
        }
        try saveContext()
    }

    public func load(context gameContext: GameContext) throws -> SavedGame? {
        guard let entity = try fetchEntity(contextKey: gameContext.contextKey) else { return nil }
        return try PersistenceMappers.decode(SavedGame.self, from: entity.payload)
    }

    public func delete(context gameContext: GameContext) throws {
        guard let entity = try fetchEntity(contextKey: gameContext.contextKey) else { return }
        context.delete(entity)
        try saveContext()
    }

    private func fetchEntity(contextKey: String) throws -> SavedGameEntity? {
        var descriptor = FetchDescriptor<SavedGameEntity>(
            predicate: #Predicate { $0.contextKey == contextKey },
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw DomainError.persistence
        }
    }

    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            throw DomainError.persistence
        }
    }
}
