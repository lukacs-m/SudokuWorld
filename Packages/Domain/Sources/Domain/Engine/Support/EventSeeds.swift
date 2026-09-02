public import Foundation
public import Model

/// Deterministic scheduling for events: every player derives the same daily
/// puzzle seed and the same weekly tournament theme from the calendar alone.
/// All keys use UTC so a challenge never differs across time zones.
public enum EventSeeds {
    /// A UTC Gregorian calendar — the single clock authority for events.
    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    // MARK: - Daily challenge

    /// "2026-07-04" for the UTC day containing `date`.
    public static func dailyDateKey(for date: Date) -> String {
        let parts = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0,
        )
    }

    /// The shared worldwide seed for one of a day's challenges.
    public static func dailySeed(dateKey: String, variant: SudokuVariant) -> UInt64 {
        SplitMix64.evolve(fnv1a("daily:\(dateKey):\(variant.slug)"))
    }

    // MARK: - Daily rotation

    /// Non-classic variants split by how quickly a newcomer picks them up.
    /// Each day pairs one variant from each bucket; a bucket cycles on its
    /// own length, so the two need not be the same size.
    static let accessibleRotation: [SudokuVariant] = [
        .mini4, .mini6, .diagonal, .windoku, .evenOdd, .asterisk, .argyle,
        .jigsaw, .wordoku, .kropki, .xv, .consecutive, .greaterThan, .thermo,
        .antiKnight, .antiKing, .fogOfWar, .dodeka12,
    ]

    static let complexRotation: [SudokuVariant] = [
        .killer, .killerGT, .arrow, .sandwich, .skyscraper, .littleKiller,
        .miracle, .samurai, .gattai2, .gattai3, .gattai8, .shogun, .sumo,
        .tredoku, .cube, .hexadoku16, .alphadoku25,
    ]

    /// Every player's three challenges for a UTC day: classic plus one
    /// accessible and one complex variant. A seeded shuffle per bucket cycle
    /// covers that bucket with no repeats inside the cycle.
    public static func dailySlots(dateKey: String)
        -> [(variant: SudokuVariant, difficulty: Difficulty)]
    {
        let day = dayNumber(dateKey: dateKey)
        let accessible = pick(from: accessibleRotation, bucket: "accessible", day: day)
        let complex = pick(from: complexRotation, bucket: "complex", day: day)
        return [.classic, accessible, complex].map { variant in
            (variant, dailyDifficulty(dateKey: dateKey, variant: variant))
        }
    }

    private static func pick(from rotation: [SudokuVariant], bucket: String, day: Int) -> SudokuVariant {
        let (cycle, position) = floorDiv(day, rotation.count)
        var rng = Xoshiro256StarStar(seed: SplitMix64.evolve(fnv1a("rotation:\(bucket):\(cycle)")))
        return rotation.shuffled(using: &rng)[position]
    }

    /// The next UTC day after `dateKey` whose rotation includes `variant`.
    /// Classic runs every day, so it has no "next" appearance.
    public static func nextAppearance(
        of variant: SudokuVariant,
        after dateKey: String,
    ) -> String? {
        guard variant != .classic, let start = date(fromDateKey: dateKey) else { return nil }
        let calendar = utcCalendar
        // A variant appears once per cycle; two cycles bound the scan.
        let longestCycle = max(accessibleRotation.count, complexRotation.count)
        for offset in 1 ... (2 * longestCycle) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                continue
            }
            let key = dailyDateKey(for: day)
            if dailySlots(dateKey: key).contains(where: { $0.variant == variant }) {
                return key
            }
        }
        return nil
    }

    /// Difficulty weighted toward the easy end so dailies stay broadly
    /// playable; classic gets the wider beginner...hard band.
    static func dailyDifficulty(dateKey: String, variant: SudokuVariant) -> Difficulty {
        let table: [Difficulty] = variant == .classic
            ? [.beginner, .easy, .easy, .medium, .medium, .hard]
            : [.easy, .easy, .medium, .medium, .hard]
        let index = Int(fnv1a("dailydiff:\(dateKey):\(variant.slug)") % UInt64(table.count))
        return table[index]
    }

    /// Whole days between the fixed rotation epoch (2026-01-01 UTC) and the
    /// day named by `dateKey`.
    static func dayNumber(dateKey: String) -> Int {
        let calendar = utcCalendar
        guard let day = date(fromDateKey: dateKey),
              let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
        else { return 0 }
        return calendar.dateComponents([.day], from: epoch, to: day).day ?? 0
    }

    /// Midnight UTC starting the day named by `dateKey`.
    public static func date(fromDateKey dateKey: String) -> Date? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return utcCalendar.date(from: DateComponents(
            year: parts[0],
            month: parts[1],
            day: parts[2],
        ))
    }

    /// Floored division so pre-epoch days still map into a stable cycle.
    private static func floorDiv(_ value: Int, _ divisor: Int) -> (Int, Int) {
        var quotient = value / divisor
        var remainder = value % divisor
        if remainder < 0 {
            quotient -= 1
            remainder += divisor
        }
        return (quotient, remainder)
    }

    /// The next UTC midnight after `date` — when the daily lineup rotates.
    public static func nextDailyReset(after date: Date) -> Date {
        let calendar = utcCalendar
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
    }

    // MARK: - Weekly tournament

    /// "2026-W27" for the ISO week containing `date` (UTC).
    public static func weekKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    /// The themed variant × difficulty for a tournament week. Fixed rotation
    /// table indexed by a week-key hash, so every player sees the same theme.
    public static func weeklyPlan(weekKey: String)
        -> (variant: SudokuVariant, difficulty: Difficulty)
    {
        let rotation: [(SudokuVariant, Difficulty)] = [
            (.classic, .hard),
            (.killer, .medium),
            (.diagonal, .hard),
            (.windoku, .medium),
            (.evenOdd, .hard),
            (.mini6, .medium),
            (.classic, .expert),
            (.killer, .hard),
        ]
        let index = Int(fnv1a("weekly:\(weekKey)") % UInt64(rotation.count))
        return rotation[index]
    }

    /// The end of the ISO week containing `date` (next Monday 00:00 UTC).
    public static func weekEnd(for date: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date,
        )
        guard let weekStart = calendar.date(from: components),
              let end = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)
        else { return date }
        return end
    }

    // MARK: - Hashing

    /// FNV-1a 64-bit over UTF-8 — a stable, platform-independent string hash.
    /// (Never use `String.hashValue`: it is randomized per process.)
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
