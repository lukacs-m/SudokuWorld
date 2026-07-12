/// Streak counters surfaced on the home and stats screens.
public struct StreakInfo: Equatable, Sendable, Codable {
    /// Consecutive calendar days with a completed daily challenge.
    public let currentDailyStreak: Int
    public let bestDailyStreak: Int
    /// Consecutive wins across all finished games.
    public let currentWinStreak: Int
    public let bestWinStreak: Int

    public static let zero = StreakInfo(
        currentDailyStreak: 0,
        bestDailyStreak: 0,
        currentWinStreak: 0,
        bestWinStreak: 0,
    )

    public init(
        currentDailyStreak: Int,
        bestDailyStreak: Int,
        currentWinStreak: Int,
        bestWinStreak: Int,
    ) {
        self.currentDailyStreak = currentDailyStreak
        self.bestDailyStreak = bestDailyStreak
        self.currentWinStreak = currentWinStreak
        self.bestWinStreak = bestWinStreak
    }
}
