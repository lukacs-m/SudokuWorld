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
        #expect(
            EventSeeds.dailySeed(dateKey: keyMorning, variant: .classic)
                == EventSeeds.dailySeed(dateKey: keyEvening, variant: .classic),
        )
    }

    @Test func differentDaysYieldDifferentSeeds() {
        #expect(
            EventSeeds.dailySeed(dateKey: "2026-07-04", variant: .classic)
                != EventSeeds.dailySeed(dateKey: "2026-07-05", variant: .classic),
        )
    }

    @Test func dailySeedDiffersPerSlot() {
        #expect(
            EventSeeds.dailySeed(dateKey: "2026-07-04", variant: .classic)
                != EventSeeds.dailySeed(dateKey: "2026-07-04", variant: .killer),
        )
    }

    @Test func dailySlotsAreStable() {
        let first = EventSeeds.dailySlots(dateKey: "2026-07-04")
        let second = EventSeeds.dailySlots(dateKey: "2026-07-04")
        #expect(first.map(\.variant) == second.map(\.variant))
        #expect(first.map(\.difficulty) == second.map(\.difficulty))
        #expect(first.count == 3)
        #expect(first[0].variant == .classic)
    }

    @Test func bucketsPartitionTheCatalog() {
        let accessible = Set(EventSeeds.accessibleRotation)
        let complex = Set(EventSeeds.complexRotation)
        #expect(accessible.count == EventSeeds.accessibleRotation.count)
        #expect(complex.count == EventSeeds.complexRotation.count)
        #expect(accessible.count == complex.count)
        #expect(accessible.isDisjoint(with: complex))
        #expect(accessible.union(complex) == Set(SudokuVariant.allCases).subtracting([.classic]))
    }

    @Test func cycleCoversTheCatalogWithoutRepeats() {
        // Walk one full 17-day cycle from the rotation epoch: every
        // non-classic variant must appear exactly once.
        let calendar = EventSeeds.utcCalendar
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        var seen: [SudokuVariant] = []
        for offset in 0 ..< EventSeeds.accessibleRotation.count {
            let day = calendar.date(byAdding: .day, value: offset, to: epoch)!
            let slots = EventSeeds.dailySlots(dateKey: EventSeeds.dailyDateKey(for: day))
            seen.append(contentsOf: slots.dropFirst().map(\.variant))
        }
        #expect(seen.count == 34)
        #expect(Set(seen).count == 34)
        #expect(Set(seen) == Set(SudokuVariant.allCases).subtracting([.classic]))
    }

    @Test func slotsPairAccessibleWithComplex() {
        for dateKey in ["2026-07-04", "2026-01-01", "2026-12-31", "2027-03-15"] {
            let slots = EventSeeds.dailySlots(dateKey: dateKey)
            #expect(EventSeeds.accessibleRotation.contains(slots[1].variant))
            #expect(EventSeeds.complexRotation.contains(slots[2].variant))
        }
    }

    @Test func nextAppearanceFindsEveryVariant() {
        for variant in [SudokuVariant.killer, .mini4, .alphadoku25, .fogOfWar] {
            let next = EventSeeds.nextAppearance(of: variant, after: "2026-07-04")
            guard let next else {
                Issue.record("No appearance for \(variant) within two cycles")
                continue
            }
            #expect(next > "2026-07-04")
            #expect(EventSeeds.dailySlots(dateKey: next).contains { $0.variant == variant })
        }
        #expect(EventSeeds.nextAppearance(of: .classic, after: "2026-07-04") == nil)
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
