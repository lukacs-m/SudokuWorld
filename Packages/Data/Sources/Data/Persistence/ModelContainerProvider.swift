import Common
import Foundation
import SwiftData

/// Owns the app's single on-disk `ModelContainer`. Internal on purpose: no
/// SwiftData type ever appears in a public API, so the `public import` rule
/// keeps the framework fenced inside the Data layer.
enum ModelContainerProvider {
    /// The shared store. Falls back to an in-memory container when the store
    /// can't be opened (disk full, corrupt file) — the app must never crash
    /// at launch over persistence.
    static let shared: ModelContainer = {
        do {
            return try makeContainer(inMemory: false)
        } catch {
            Log.error("Failed to open the persistent store, falling back to in-memory: \(error)")
            do {
                return try makeContainer(inMemory: true)
            } catch {
                // Creating an in-memory store allocates no resources that can
                // realistically fail; reaching this means SwiftData itself is
                // broken and nothing in the app could work anyway.
                fatalError("Unable to create even an in-memory store: \(error)")
            }
        }
    }()

    /// A throwaway store for tests.
    static func inMemory() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    private static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: SudokuWorldMigrationPlan.self,
            configurations: [configuration],
        )
    }
}
