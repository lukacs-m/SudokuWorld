public import Domain
import Foundation
public import Model
import SwiftData

/// SwiftData-backed history of finished games.
public actor SwiftDataGameRecordRepository: GameRecordRepository {
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

    public func insert(_ record: GameRecord) throws {
        let payload = try PersistenceMappers.encode(record)
        context.insert(GameRecordEntity(
            id: record.id,
            finishedAt: record.finishedAt,
            payload: payload,
        ))
        do {
            try context.save()
        } catch {
            throw DomainError.persistence
        }
    }

    public func allRecords() throws -> [GameRecord] {
        let descriptor = FetchDescriptor<GameRecordEntity>(
            sortBy: [SortDescriptor(\.finishedAt, order: .reverse)],
        )
        do {
            let entities = try context.fetch(descriptor)
            return try entities.map {
                try PersistenceMappers.decode(GameRecord.self, from: $0.payload)
            }
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.persistence
        }
    }
}
