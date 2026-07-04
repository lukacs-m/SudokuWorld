public import Model

/// The single source of truth for every Game Center identifier. Everything
/// derives from `prefix` — change it here and the whole ID matrix follows.
/// A unit test pins the expected counts (84 matrix + 4 aggregate leaderboards,
/// 16 achievements) so a rename can never silently desync code from
/// App Store Connect.
public enum GameCenterIDs {
    public static let prefix = "com.mlukacs.sudokuWorld"

    // MARK: - Leaderboards

    public enum Metric: String, CaseIterable, Sendable {
        case time = "lb.time"
        case wins = "lb.wins"
    }

    /// `com.mlukacs.sudokuWorld.lb.time.classic.expert` and friends.
    public static func leaderboard(
        _ metric: Metric,
        _ variant: SudokuVariant,
        _ difficulty: Difficulty,
    ) -> String {
        "\(prefix).\(metric.rawValue).\(variant.slug).\(difficulty.slug)"
    }

    /// Total wins across every variant and difficulty (higher is better).
    public static let winsAll = "\(prefix).lb.wins.all"
    /// Best daily-challenge streak (higher is better).
    public static let bestStreak = "\(prefix).lb.streak.best"
    /// Daily challenge, recurring; score = completion centiseconds.
    public static let daily = "\(prefix).lb.daily"
    /// Weekly tournament, recurring; score = cumulative points.
    public static let weekly = "\(prefix).lb.weekly"

    /// The 7 variants × 6 difficulties × 2 metrics = 84 matrix boards.
    public static var matrixLeaderboardIDs: [String] {
        SudokuVariant.allCases.flatMap { variant in
            Difficulty.allCases.flatMap { difficulty in
                Metric.allCases.map { metric in
                    leaderboard(metric, variant, difficulty)
                }
            }
        }
    }

    /// Matrix boards plus the four aggregates — 88 in total.
    public static var allLeaderboardIDs: [String] {
        matrixLeaderboardIDs + [winsAll, bestStreak, daily, weekly]
    }

    // MARK: - Achievements

    public enum Achievement: String, CaseIterable, Sendable {
        case firstWin = "firstwin"
        case wins10 = "wins.10"
        case wins100 = "wins.100"
        case wins1000 = "wins.1000"
        case speedExpert3 = "speed.expert3"
        case speedMaster5 = "speed.master5"
        case noHintExpert = "nohint.expert"
        case flawlessHard = "flawless.hard"
        case streak7 = "streak.7"
        case streak30 = "streak.30"
        case variety
        case killerMaster = "killer.master"
        case samurai
        case dailyFirst = "daily.first"
        case weeklyPodium = "weekly.podium"
        case night

        /// The full App Store Connect identifier.
        public var id: String {
            "\(GameCenterIDs.prefix).ach.\(rawValue)"
        }

        /// Game Center points (≤ 1000 total across all achievements).
        public var points: Int {
            switch self {
            case .firstWin: 5
            case .wins10: 10
            case .wins100: 25
            case .wins1000: 100
            case .speedExpert3: 25
            case .speedMaster5: 40
            case .noHintExpert: 20
            case .flawlessHard: 20
            case .streak7: 15
            case .streak30: 50
            case .variety: 30
            case .killerMaster: 30
            case .samurai: 25
            case .dailyFirst: 10
            case .weeklyPodium: 40
            case .night: 5
            }
        }

        /// Hidden until earned (the "night owl" easter egg).
        public var isHidden: Bool {
            self == .night
        }
    }
}
