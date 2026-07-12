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

    /// The shared worldwide seed for a daily challenge.
    public static func dailySeed(dateKey: String) -> UInt64 {
        SplitMix64.evolve(fnv1a("daily:\(dateKey)"))
    }

    /// The variant × difficulty a given day's challenge uses. Rotates through
    /// an accessible mix — samurai is excluded, and difficulty stays in the
    /// beginner...hard band so the daily remains broadly playable.
    public static func dailyPlan(dateKey: String)
        -> (variant: SudokuVariant, difficulty: Difficulty)
    {
        let rotation: [(SudokuVariant, Difficulty)] = [
            (.classic, .easy),
            (.mini6, .medium),
            (.diagonal, .medium),
            (.classic, .hard),
            (.evenOdd, .easy),
            (.windoku, .medium),
            (.killer, .medium),
            (.classic, .medium),
            (.mini6, .easy),
            (.diagonal, .hard),
            (.evenOdd, .medium),
            (.windoku, .hard),
            (.killer, .easy),
            (.classic, .beginner),
        ]
        let index = Int(fnv1a("plan:\(dateKey)") % UInt64(rotation.count))
        return rotation[index]
    }

    /// The next UTC midnight after `date` — when the daily challenge rotates.
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
