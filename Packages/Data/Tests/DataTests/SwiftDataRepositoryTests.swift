import Domain
import Foundation
import Model
import Testing
@testable import Data

@Suite
struct SavedGameRepositoryTests {
    private func makeRepository() throws -> SwiftDataSavedGameRepository {
        SwiftDataSavedGameRepository(container: try ModelContainerProvider.inMemory())
    }

    @Test func saveAndLoadRoundtrip() async throws {
        let repository = try makeRepository()
        let game = PersistenceFixtures.savedGame()

        try await repository.save(game)
        let loaded = try await repository.load(context: .regular)
        #expect(loaded == game)
    }

    @Test func loadMissingReturnsNil() async throws {
        let repository = try makeRepository()
        let loaded = try await repository.load(context: .regular)
        #expect(loaded == nil)
    }

    @Test func saveUpsertsPerContextKey() async throws {
        let repository = try makeRepository()
        let first = PersistenceFixtures.savedGame(elapsed: 10)
        let second = PersistenceFixtures.savedGame(elapsed: 99)

        try await repository.save(first)
        try await repository.save(second)
        let loaded = try await repository.load(context: .regular)
        #expect(loaded?.elapsed == 99)
    }

    @Test func contextsAreIndependent() async throws {
        let repository = try makeRepository()
        let main = PersistenceFixtures.savedGame(context: .regular, elapsed: 11)
        let daily = PersistenceFixtures.savedGame(
            context: .daily(dateKey: "2026-07-04"),
            elapsed: 22,
        )

        try await repository.save(main)
        try await repository.save(daily)

        let loadedMain = try await repository.load(context: .regular)
        let loadedDaily = try await repository.load(context: .daily(dateKey: "2026-07-04"))
        #expect(loadedMain?.elapsed == 11)
        #expect(loadedDaily?.elapsed == 22)
    }

    @Test func deleteRemovesOnlyThatContext() async throws {
        let repository = try makeRepository()
        try await repository.save(PersistenceFixtures.savedGame(context: .regular))
        try await repository.save(
            PersistenceFixtures.savedGame(context: .weekly(weekKey: "2026-W27")),
        )

        try await repository.delete(context: .regular)
        let main = try await repository.load(context: .regular)
        let weekly = try await repository.load(context: .weekly(weekKey: "2026-W27"))
        #expect(main == nil)
        #expect(weekly != nil)
    }
}

@Suite
struct GameRecordRepositoryTests {
    private func makeRepository() throws -> SwiftDataGameRecordRepository {
        SwiftDataGameRecordRepository(container: try ModelContainerProvider.inMemory())
    }

    @Test func insertAndFetchRoundtrip() async throws {
        let repository = try makeRepository()
        let record = PersistenceFixtures.record()

        try await repository.insert(record)
        let all = try await repository.allRecords()
        #expect(all == [record])
    }

    @Test func recordsComeBackNewestFirst() async throws {
        let repository = try makeRepository()
        let older = PersistenceFixtures.record(
            finishedAt: Date(timeIntervalSince1970: 1_000),
        )
        let newer = PersistenceFixtures.record(
            finishedAt: Date(timeIntervalSince1970: 2_000),
        )

        try await repository.insert(older)
        try await repository.insert(newer)
        let all = try await repository.allRecords()
        #expect(all.map(\.id) == [newer.id, older.id])
    }
}

@Suite
struct DailyChallengeRepositoryTests {
    private func makeRepository() throws -> SwiftDataDailyChallengeRepository {
        SwiftDataDailyChallengeRepository(container: try ModelContainerProvider.inMemory())
    }

    @Test func markCompletedRecordsTheDay() async throws {
        let repository = try makeRepository()
        try await repository.markCompleted(dateKey: "2026-07-04", duration: 300, at: Date())

        let keys = try await repository.completedDateKeys()
        #expect(keys == ["2026-07-04"])
        let time = try await repository.completionTime(dateKey: "2026-07-04")
        #expect(time == 300)
    }

    @Test func repeatCompletionKeepsBestTime() async throws {
        let repository = try makeRepository()
        try await repository.markCompleted(dateKey: "2026-07-04", duration: 300, at: Date())
        try await repository.markCompleted(dateKey: "2026-07-04", duration: 250, at: Date())
        try await repository.markCompleted(dateKey: "2026-07-04", duration: 400, at: Date())

        let time = try await repository.completionTime(dateKey: "2026-07-04")
        #expect(time == 250)
        let keys = try await repository.completedDateKeys()
        #expect(keys.count == 1)
    }

    @Test func missingCompletionIsNil() async throws {
        let repository = try makeRepository()
        let time = try await repository.completionTime(dateKey: "2026-01-01")
        #expect(time == nil)
    }

    @Test func tournamentScoreRoundtrip() async throws {
        let repository = try makeRepository()
        let score = TournamentScore(
            weekKey: "2026-W27",
            points: 1100,
            gamesCounted: 2,
            lastSubmittedPoints: 1100,
        )
        try await repository.saveTournamentScore(score)
        let loaded = try await repository.tournamentScore(weekKey: "2026-W27")
        #expect(loaded == score)
    }

    @Test func tournamentScoreUpserts() async throws {
        let repository = try makeRepository()
        var score = TournamentScore(
            weekKey: "2026-W27",
            points: 500,
            gamesCounted: 1,
            lastSubmittedPoints: 0,
        )
        try await repository.saveTournamentScore(score)
        score.points = 1200
        score.gamesCounted = 2
        try await repository.saveTournamentScore(score)

        let loaded = try await repository.tournamentScore(weekKey: "2026-W27")
        #expect(loaded?.points == 1200)
        #expect(loaded?.gamesCounted == 2)
    }
}

@Suite
struct AdStateRepositoryTests {
    @Test func countersAccumulateAndReset() async {
        let suite = "test.adstate.\(UUID().uuidString)"
        let repository = UserDefaultsAdStateRepository(suiteName: suite)
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        let initial = await repository.gamesFinishedSinceInterstitial()
        #expect(initial == 0)

        await repository.recordGameFinished()
        await repository.recordGameFinished()
        let afterTwo = await repository.gamesFinishedSinceInterstitial()
        #expect(afterTwo == 2)

        let shownAt = Date(timeIntervalSince1970: 1_700_000_000)
        await repository.recordInterstitialShown(at: shownAt)
        let afterShow = await repository.gamesFinishedSinceInterstitial()
        #expect(afterShow == 0)
        let lastShown = await repository.lastInterstitialShownAt()
        #expect(lastShown == shownAt)
    }
}

@Suite
struct SettingsRepositoryTests {
    @Test func settingsRoundtrip() async {
        let suite = "test.settings.\(UUID().uuidString)"
        let repository = UserDefaultsSettingsRepository(suiteName: suite)
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        let defaults = await repository.gameSettings()
        #expect(defaults == .standard)

        var custom = GameSettings.standard
        custom.inputMode = .digitFirst
        custom.hardcoreByDefault = true
        custom.theme = .midnight
        await repository.setGameSettings(custom)
        let loaded = await repository.gameSettings()
        #expect(loaded == custom)

        var prefs = NotificationPreferences.disabled
        prefs.dailyReminderEnabled = true
        prefs.reminderHour = 8
        await repository.setNotificationPreferences(prefs)
        let loadedPrefs = await repository.notificationPreferences()
        #expect(loadedPrefs == prefs)
    }
}
