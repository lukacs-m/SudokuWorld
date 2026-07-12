import Foundation
import SwiftData

/// Version 1 of the persistence schema. Engine types (puzzle, board, moves)
/// are stored as JSON payloads so their evolution never forces a store
/// migration; entities only carry the columns needed for lookups and sorts.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            SavedGameEntity.self,
            GameRecordEntity.self,
            DailyCompletionEntity.self,
            TournamentScoreEntity.self,
        ]
    }
}

/// Ready for SchemaV2: add the new schema, a migration stage, and bump the
/// container's `migrationPlan` — nothing else changes.
enum SudokuWorldMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

/// One resumable game per context key ("main", "daily:<date>", "weekly:<week>").
@Model
final class SavedGameEntity {
    @Attribute(.unique) var contextKey: String
    /// JSON-encoded `SavedGame`.
    var payload: Data
    var updatedAt: Date

    init(contextKey: String, payload: Data, updatedAt: Date) {
        self.contextKey = contextKey
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

/// One finished game.
@Model
final class GameRecordEntity {
    @Attribute(.unique) var id: UUID
    var finishedAt: Date
    /// JSON-encoded `GameRecord`.
    var payload: Data

    init(id: UUID, finishedAt: Date, payload: Data) {
        self.id = id
        self.finishedAt = finishedAt
        self.payload = payload
    }
}

/// One row per completed daily challenge — the daily-streak history.
@Model
final class DailyCompletionEntity {
    @Attribute(.unique) var dateKey: String
    var completedAt: Date
    var durationSeconds: Double

    init(dateKey: String, completedAt: Date, durationSeconds: Double) {
        self.dateKey = dateKey
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
    }
}

/// The local player's weekly tournament tally.
@Model
final class TournamentScoreEntity {
    @Attribute(.unique) var weekKey: String
    var points: Int
    var gamesCounted: Int
    var lastSubmittedPoints: Int
    var updatedAt: Date

    init(
        weekKey: String,
        points: Int,
        gamesCounted: Int,
        lastSubmittedPoints: Int,
        updatedAt: Date,
    ) {
        self.weekKey = weekKey
        self.points = points
        self.gamesCounted = gamesCounted
        self.lastSubmittedPoints = lastSubmittedPoints
        self.updatedAt = updatedAt
    }
}
