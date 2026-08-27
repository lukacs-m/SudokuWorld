public import Domain
public import Foundation
public import Model
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

    public func completedDays() throws -> Set<String> {
        let descriptor = FetchDescriptor<DailyCompletionEntity>()
        do {
            let rows = try context.fetch(descriptor)
            // Keyed to when the player solved, not which day's puzzle:
            // finishing any daily today credits today; a past day can never
            // be minted after the fact (no streak repair, paid or not).
            return Set(rows.map { EventSeeds.dailyDateKey(for: $0.completedAt) })
        } catch {
            throw DomainError.persistence
        }
    }

    public func completions(dateKey: String) throws -> [SudokuVariant: TimeInterval] {
        let descriptor = FetchDescriptor<DailyCompletionEntity>(
            predicate: #Predicate { $0.dateKey == dateKey },
        )
        do {
            return try context.fetch(descriptor).reduce(into: [:]) { times, row in
                guard let variant = SudokuVariant(rawValue: row.variantSlug) else { return }
                times[variant] = row.durationSeconds
            }
        } catch {
            throw DomainError.persistence
        }
    }

    public func markCompleted(
        dateKey: String,
        variant: SudokuVariant,
        duration: TimeInterval,
        at date: Date,
    ) throws {
        let key = "\(dateKey):\(variant.slug)"
        if let existing = try fetchCompletion(key: key) {
            // Keep the best time for the slot.
            existing.durationSeconds = min(existing.durationSeconds, duration)
        } else {
            context.insert(DailyCompletionEntity(
                key: key,
                dateKey: dateKey,
                variantSlug: variant.slug,
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

    private func fetchCompletion(key: String) throws -> DailyCompletionEntity? {
        var descriptor = FetchDescriptor<DailyCompletionEntity>(
            predicate: #Predicate { $0.key == key },
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
