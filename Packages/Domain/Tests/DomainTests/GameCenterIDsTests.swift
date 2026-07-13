import Testing
@testable import Domain
import Model

/// Pins the Game Center identifier matrix. If a slug or the prefix ever
/// drifts from what App Store Connect has, these fail loudly.
@Suite
struct GameCenterIDsTests {
    @Test func matrixHas84Boards() {
        let ids = GameCenterIDs.matrixLeaderboardIDs
        #expect(ids.count == 84)
        #expect(Set(ids).count == 84)
    }

    /// The matrix must stay pinned to the curated seven that exist in
    /// App Store Connect — new variants must NOT silently mint board IDs.
    @Test func matrixCoversOnlyCuratedVariants() {
        #expect(GameCenterIDs.leaderboardVariants.map(\.slug) == [
            "classic", "mini6", "killer", "diagonal", "windoku", "evenodd", "samurai",
        ])
        for variant in SudokuVariant.allCases
            where !GameCenterIDs.leaderboardVariants.contains(variant) {
            let ids = GameCenterIDs.matrixLeaderboardIDs
            #expect(!ids.contains { $0.contains(".\(variant.slug).") })
        }
    }

    @Test func allBoardsIncludeAggregates() {
        let ids = GameCenterIDs.allLeaderboardIDs
        #expect(ids.count == 88)
        #expect(Set(ids).count == 88)
        #expect(ids.contains(GameCenterIDs.winsAll))
        #expect(ids.contains(GameCenterIDs.bestStreak))
        #expect(ids.contains(GameCenterIDs.daily))
        #expect(ids.contains(GameCenterIDs.weekly))
    }

    @Test func sixteenAchievements() {
        #expect(GameCenterIDs.Achievement.allCases.count == 16)
        let ids = GameCenterIDs.Achievement.allCases.map(\.id)
        #expect(Set(ids).count == 16)
    }

    @Test func everyIDDerivesFromThePrefix() {
        for id in GameCenterIDs.allLeaderboardIDs {
            #expect(id.hasPrefix(GameCenterIDs.prefix))
        }
        for achievement in GameCenterIDs.Achievement.allCases {
            #expect(achievement.id.hasPrefix("\(GameCenterIDs.prefix).ach."))
        }
    }

    @Test func leaderboardIDFormat() {
        let id = GameCenterIDs.leaderboard(.time, .classic, .expert)
        #expect(id == "com.mlukacs.sudokuWorld.lb.time.classic.expert")
        let wins = GameCenterIDs.leaderboard(.wins, .killer, .hard)
        #expect(wins == "com.mlukacs.sudokuWorld.lb.wins.killer.hard")
    }

    @Test func slugsAreCanonical() {
        #expect(SudokuVariant.allCases.map(\.slug) == [
            "classic", "mini6", "killer", "diagonal", "windoku", "evenodd", "samurai",
            "mini4", "dodeka12", "hexadoku16", "wordoku",
            "jigsaw", "argyle", "asterisk",
            "gattai2", "gattai3", "gattai8", "shogun", "sumo",
            "alphadoku25", "antiknight", "antiking",
            "greaterthan", "kropki", "xv", "consecutive", "miracle",
            "thermo", "arrow",
            "sandwich", "skyscraper", "littlekiller",
            "fogofwar", "killergt", "tredoku",
        ])
        #expect(Difficulty.allCases.map(\.slug) == [
            "beginner", "easy", "medium", "hard", "expert", "master",
        ])
    }

    @Test func achievementPointsWithinGameCenterBudget() {
        // The spec's table values sum to 450 (its prose says 470 — an
        // arithmetic slip), comfortably under Game Center's 1000-point cap.
        let total = GameCenterIDs.Achievement.allCases.reduce(0) { $0 + $1.points }
        #expect(total == 450)
        #expect(total <= 1000)
    }
}
