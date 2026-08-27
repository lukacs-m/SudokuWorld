import Foundation
import Model
import Testing
@testable import Domain

private struct StubDailyRepository: DailyChallengeRepository {
    var times: [SudokuVariant: TimeInterval] = [:]

    func completedDays() async throws -> Set<String> { [] }
    func completions(dateKey: String) async throws -> [SudokuVariant: TimeInterval] { times }
    func markCompleted(
        dateKey: String,
        variant: SudokuVariant,
        duration: TimeInterval,
        at date: Date,
    ) async throws {}
    func tournamentScore(weekKey: String) async throws -> TournamentScore? { nil }
    func saveTournamentScore(_ score: TournamentScore) async throws {}
}

@Suite
struct GetDailyLineupTests {
    @Test func slotsFollowRotationAndMergeCompletions() async {
        let plans = EventSeeds.dailySlots(dateKey: "2026-07-04")
        let done = plans[1].variant
        let useCase = GetDailyLineup(dailyChallenges: StubDailyRepository(times: [done: 321]))

        let lineup = await useCase(dateKey: "2026-07-04")

        #expect(lineup.dateKey == "2026-07-04")
        #expect(lineup.slots.map(\.variant) == plans.map(\.variant))
        #expect(lineup.slots.map(\.difficulty) == plans.map(\.difficulty))
        #expect(lineup.slots[1].completionTime == 321)
        #expect(lineup.slots[1].isCompleted)
        #expect(!lineup.slots[0].isCompleted)
        // The lineup ends at that day's UTC midnight — also true for
        // archived days, whose end lies in the past.
        #expect(EventSeeds.dailyDateKey(for: lineup.endsAt.addingTimeInterval(-1)) == "2026-07-04")
    }
}
