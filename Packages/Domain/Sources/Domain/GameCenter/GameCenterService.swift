public import Model

/// Progress report for one achievement, as a percentage (0...100). Milestone
/// achievements (win counts, streaks) report incrementally; one-shot
/// achievements report 100 when earned.
public struct AchievementProgress: Equatable, Sendable {
    public let achievement: GameCenterIDs.Achievement
    public let percent: Double

    public init(achievement: GameCenterIDs.Achievement, percent: Double) {
        self.achievement = achievement
        self.percent = min(100, max(0, percent))
    }
}

/// GameKit abstraction. Implementations must never block gameplay: every
/// call is safe when unauthenticated or offline and simply degrades (queued
/// or dropped submissions, empty standings).
public protocol GameCenterService: Sendable {
    /// Kicks off (or re-checks) authentication. Never throws — the resulting
    /// state flows through `authStateStream`.
    func authenticate() async
    func currentAuthState() async -> GameCenterAuthState
    func authStateStream() -> AsyncStream<GameCenterAuthState>

    /// Fire-and-forget score submission (times in centiseconds, wins/points
    /// as plain integers). Queued for retry when offline.
    func submitScore(_ value: Int, leaderboardID: String) async
    /// Fire-and-forget achievement progress reporting.
    func report(_ progress: [AchievementProgress]) async

    /// Top entries plus the local player's own entry for one leaderboard.
    func standings(leaderboardID: String, count: Int) async throws -> LeaderboardStandings

    /// Debug-menu support only.
    func resetAchievements() async throws
}
