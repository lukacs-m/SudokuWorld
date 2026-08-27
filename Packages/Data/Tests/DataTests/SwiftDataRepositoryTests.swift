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
            context: .daily(dateKey: "2026-07-04", variant: .classic),
            elapsed: 22,
        )

        try await repository.save(main)
        try await repository.save(daily)

        let loadedMain = try await repository.load(context: .regular)
        let loadedDaily = try await repository.load(
            context: .daily(dateKey: "2026-07-04", variant: .classic),
        )
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

    /// Noon UTC on the day named by the key, so completions count as on-day.
    private func noon(_ dateKey: String) -> Date {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        components.hour = 12
        return EventSeeds.utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    @Test func markCompletedRecordsTheSlot() async throws {
        let repository = try makeRepository()
        try await repository.markCompleted(
            dateKey: "2026-07-04",
            variant: .classic,
            duration: 300,
            at: noon("2026-07-04"),
        )

        let days = try await repository.completedDays()
        #expect(days == ["2026-07-04"])
        let times = try await repository.completions(dateKey: "2026-07-04")
        #expect(times == [.classic: 300])
    }

    @Test func slotsOfADayAreIndependent() async throws {
        let repository = try makeRepository()
        let at = noon("2026-07-04")
        try await repository.markCompleted(
            dateKey: "2026-07-04", variant: .classic, duration: 300, at: at,
        )
        try await repository.markCompleted(
            dateKey: "2026-07-04", variant: .killer, duration: 500, at: at,
        )

        let times = try await repository.completions(dateKey: "2026-07-04")
        #expect(times == [.classic: 300, .killer: 500])
        let days = try await repository.completedDays()
        #expect(days == ["2026-07-04"])
    }

    @Test func repeatCompletionKeepsBestTime() async throws {
        let repository = try makeRepository()
        let at = noon("2026-07-04")
        for duration in [300.0, 250, 400] {
            try await repository.markCompleted(
                dateKey: "2026-07-04", variant: .classic, duration: duration, at: at,
            )
        }

        let times = try await repository.completions(dateKey: "2026-07-04")
        #expect(times[.classic] == 250)
    }

    @Test func replayCreditsTheCompletionDayNotThePuzzleDay() async throws {
        let repository = try makeRepository()
        // July 4th's puzzle, solved on July 6th: the slot shows as done and
        // July 6th joins the streak history — July 4th never does.
        try await repository.markCompleted(
            dateKey: "2026-07-04",
            variant: .classic,
            duration: 300,
            at: noon("2026-07-06"),
        )

        let times = try await repository.completions(dateKey: "2026-07-04")
        #expect(times == [.classic: 300])
        let days = try await repository.completedDays()
        #expect(days == ["2026-07-06"])
    }

    @Test func repeatReplayNeverMintsANewDay() async throws {
        let repository = try makeRepository()
        try await repository.markCompleted(
            dateKey: "2026-07-04", variant: .classic, duration: 300, at: noon("2026-07-04"),
        )
        // Replaying the same slot later only improves the time — the
        // original completion day stands.
        try await repository.markCompleted(
            dateKey: "2026-07-04", variant: .classic, duration: 200, at: noon("2026-07-09"),
        )

        let days = try await repository.completedDays()
        #expect(days == ["2026-07-04"])
        let times = try await repository.completions(dateKey: "2026-07-04")
        #expect(times[.classic] == 200)
    }

    @Test func missingCompletionIsEmpty() async throws {
        let repository = try makeRepository()
        let times = try await repository.completions(dateKey: "2026-01-01")
        #expect(times.isEmpty)
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
