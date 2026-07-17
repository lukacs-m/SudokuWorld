public import Domain
public import Foundation
import SwiftData

/// SwiftData-backed event progress: daily-challenge completions and weekly
/// tournament scores.
public actor SwiftDataDailyChallengeRepository: DailyChallengeRepository {
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

    // MARK: - Daily completions

    public func completedDateKeys() throws -> Set<String> {
        let descriptor = FetchDescriptor<DailyCompletionEntity>()
        do {
            return try Set(context.fetch(descriptor).map(\.dateKey))
        } catch {
            throw DomainError.persistence
        }
    }

    public func completionTime(dateKey: String) throws -> TimeInterval? {
        try fetchCompletion(dateKey: dateKey)?.durationSeconds
    }

    public func markCompleted(dateKey: String, duration: TimeInterval, at date: Date) throws {
        if let existing = try fetchCompletion(dateKey: dateKey) {
            // Keep the best time for the day.
            existing.durationSeconds = min(existing.durationSeconds, duration)
        } else {
            context.insert(DailyCompletionEntity(
                dateKey: dateKey,
                completedAt: date,
                durationSeconds: duration,
            ))
        }
        try saveContext()
    }

    // MARK: - Weekly tournament

    public func tournamentScore(weekKey: String) throws -> TournamentScore? {
        guard let entity = try fetchScore(weekKey: weekKey) else { return nil }
        return TournamentScore(
            weekKey: entity.weekKey,
            points: entity.points,
            gamesCounted: entity.gamesCounted,
            lastSubmittedPoints: entity.lastSubmittedPoints,
        )
    }

    public func saveTournamentScore(_ score: TournamentScore) throws {
        if let entity = try fetchScore(weekKey: score.weekKey) {
            entity.points = score.points
            entity.gamesCounted = score.gamesCounted
            entity.lastSubmittedPoints = score.lastSubmittedPoints
            entity.updatedAt = Date()
        } else {
            context.insert(TournamentScoreEntity(
                weekKey: score.weekKey,
                points: score.points,
                gamesCounted: score.gamesCounted,
                lastSubmittedPoints: score.lastSubmittedPoints,
                updatedAt: Date(),
            ))
        }
        try saveContext()
    }

    // MARK: - Helpers

    private func fetchCompletion(dateKey: String) throws -> DailyCompletionEntity? {
        var descriptor = FetchDescriptor<DailyCompletionEntity>(
            predicate: #Predicate { $0.dateKey == dateKey },
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw DomainError.persistence
        }
    }

    private func fetchScore(weekKey: String) throws -> TournamentScoreEntity? {
        var descriptor = FetchDescriptor<TournamentScoreEntity>(
            predicate: #Predicate { $0.weekKey == weekKey },
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
