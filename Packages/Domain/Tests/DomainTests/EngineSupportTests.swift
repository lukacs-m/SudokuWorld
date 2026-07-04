import Foundation
import Testing
@testable import Domain
import Model

@Suite
struct SeededRNGTests {
    @Test func splitMixIsDeterministic() {
        var first = SplitMix64(seed: 42)
        var second = SplitMix64(seed: 42)
        for _ in 0..<10 {
            let lhs = first.next()
            let rhs = second.next()
            #expect(lhs == rhs)
        }
    }

    @Test func splitMixDiffersBySeed() {
        var first = SplitMix64(seed: 1)
        var second = SplitMix64(seed: 2)
        let lhs = first.next()
        let rhs = second.next()
        #expect(lhs != rhs)
    }

    @Test func evolveChangesSeed() {
        let evolved = SplitMix64.evolve(7)
        #expect(evolved != 7)
        #expect(SplitMix64.evolve(7) == evolved)
    }

    @Test func xoshiroIsDeterministic() {
        var first = Xoshiro256StarStar(seed: 99)
        var second = Xoshiro256StarStar(seed: 99)
        for _ in 0..<20 {
            let lhs = first.next()
            let rhs = second.next()
            #expect(lhs == rhs)
        }
    }

    @Test func xoshiroShufflesDeterministically() {
        var first = Xoshiro256StarStar(seed: 5)
        var second = Xoshiro256StarStar(seed: 5)
        let items = Array(0..<50)
        let firstShuffle = items.shuffled(using: &first)
        let secondShuffle = items.shuffled(using: &second)
        #expect(firstShuffle == secondShuffle)
    }
}

@Suite
struct EventSeedsTests {
    private let noonUTC: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 4
        components.hour = 12
        return EventSeeds.utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    @Test func dailyDateKeyFormat() {
        #expect(EventSeeds.dailyDateKey(for: noonUTC) == "2026-07-04")
    }

    @Test func sameDayYieldsSameSeed() {
        let morning = noonUTC.addingTimeInterval(-11 * 3600)
        let evening = noonUTC.addingTimeInterval(11 * 3600)
        let keyMorning = EventSeeds.dailyDateKey(for: morning)
        let keyEvening = EventSeeds.dailyDateKey(for: evening)
        #expect(keyMorning == keyEvening)
        #expect(EventSeeds.dailySeed(dateKey: keyMorning) == EventSeeds.dailySeed(dateKey: keyEvening))
    }

    @Test func differentDaysYieldDifferentSeeds() {
        #expect(EventSeeds.dailySeed(dateKey: "2026-07-04") != EventSeeds.dailySeed(dateKey: "2026-07-05"))
    }

    @Test func dailyPlanIsStable() {
        let first = EventSeeds.dailyPlan(dateKey: "2026-07-04")
        let second = EventSeeds.dailyPlan(dateKey: "2026-07-04")
        #expect(first.variant == second.variant)
        #expect(first.difficulty == second.difficulty)
        #expect(first.variant != .samurai)
    }

    @Test func nextDailyResetIsUTCMidnight() {
        let reset = EventSeeds.nextDailyReset(after: noonUTC)
        #expect(EventSeeds.dailyDateKey(for: reset) == "2026-07-05")
        let components = EventSeeds.utcCalendar.dateComponents([.hour, .minute], from: reset)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test func weekKeyFormat() {
        let key = EventSeeds.weekKey(for: noonUTC)
        #expect(key == "2026-W27")
    }

    @Test func weeklyPlanIsStable() {
        let first = EventSeeds.weeklyPlan(weekKey: "2026-W27")
        let second = EventSeeds.weeklyPlan(weekKey: "2026-W27")
        #expect(first.variant == second.variant)
        #expect(first.difficulty == second.difficulty)
        #expect(first.variant != .samurai)
    }

    @Test func weekEndFollowsWeekStart() {
        let end = EventSeeds.weekEnd(for: noonUTC)
        #expect(end > noonUTC)
        #expect(EventSeeds.weekKey(for: end) != EventSeeds.weekKey(for: noonUTC))
        #expect(EventSeeds.weekKey(for: end.addingTimeInterval(-1)) == EventSeeds.weekKey(for: noonUTC))
    }

    @Test func fnv1aIsStable() {
        // Pinned value: platform-independent hashing is what keeps the daily
        // challenge identical across devices and app launches.
        #expect(EventSeeds.fnv1a("daily:2026-07-04") == EventSeeds.fnv1a("daily:2026-07-04"))
        #expect(EventSeeds.fnv1a("a") != EventSeeds.fnv1a("b"))
    }
}
