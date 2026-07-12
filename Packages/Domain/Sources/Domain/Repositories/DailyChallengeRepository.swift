public import Foundation

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

/// Persistence for event progress: daily-challenge completions (streak
/// history) and weekly-tournament scores.
public protocol DailyChallengeRepository: Sendable {
    func completedDateKeys() async throws -> Set<String>
    func completionTime(dateKey: String) async throws -> TimeInterval?
    func markCompleted(dateKey: String, duration: TimeInterval, at date: Date) async throws

    func tournamentScore(weekKey: String) async throws -> TournamentScore?
    func saveTournamentScore(_ score: TournamentScore) async throws
}
