public import Foundation
public import Model

/// The local player's accumulated weekly-tournament score.
/// `lastSubmittedPoints` deduplicates Game Center submissions.
public struct TournamentScore: Equatable, Sendable {
    public let weekKey: String
    public var points: Int
    public var gamesCounted: Int
    public var lastSubmittedPoints: Int

    public init(weekKey: String, points: Int, gamesCounted: Int, lastSubmittedPoints: Int) {
        self.weekKey = weekKey
        self.points = points
        self.gamesCounted = gamesCounted
        self.lastSubmittedPoints = lastSubmittedPoints
    }
}

/// Persistence for event progress: daily-slot completions (streak history)
/// and weekly-tournament scores.
public protocol DailyChallengeRepository: Sendable {
    /// UTC days on which the player first completed at least one daily slot
    /// (any day's puzzle). Past days can never be minted after the fact —
    /// no streak repair.
    func completedDays() async throws -> Set<String>
    /// Best time per completed slot of the given day.
    func completions(dateKey: String) async throws -> [SudokuVariant: TimeInterval]
    func markCompleted(
        dateKey: String,
        variant: SudokuVariant,
        duration: TimeInterval,
        at date: Date,
    ) async throws

    func tournamentScore(weekKey: String) async throws -> TournamentScore?
    func saveTournamentScore(_ score: TournamentScore) async throws
}
