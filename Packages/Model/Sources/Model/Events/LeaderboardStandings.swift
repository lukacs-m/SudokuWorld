/// A leaderboard snapshot mapped out of GameKit into plain values.
public struct LeaderboardStandings: Equatable, Sendable {
    public struct Entry: Identifiable, Equatable, Sendable {
        public let rank: Int
        public let displayName: String
        /// Pre-formatted score (GameKit formats per leaderboard config).
        public let scoreText: String
        public let isLocalPlayer: Bool

        public var id: Int {
            rank
        }

        public init(rank: Int, displayName: String, scoreText: String, isLocalPlayer: Bool) {
            self.rank = rank
            self.displayName = displayName
            self.scoreText = scoreText
            self.isLocalPlayer = isLocalPlayer
        }
    }

    public let leaderboardID: String
    public let entries: [Entry]
    /// The local player's own entry, present even when outside `entries`.
    public let localEntry: Entry?

    public init(leaderboardID: String, entries: [Entry], localEntry: Entry?) {
        self.leaderboardID = leaderboardID
        self.entries = entries
        self.localEntry = localEntry
    }
}

/// Game Center authentication, reduced to what the UI needs. Gameplay never
/// depends on this being `.authenticated`.
public enum GameCenterAuthState: Equatable, Sendable {
    case unknown
    case authenticating
    case authenticated(playerName: String)
    case unauthenticated
    /// GameKit cannot run in this environment (e.g. missing entitlement).
    case unavailable
}
