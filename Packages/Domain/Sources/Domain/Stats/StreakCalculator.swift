public import Foundation
public import Model

/// Pure streak arithmetic over daily-challenge completions and game records.
public struct StreakCalculator: Sendable {
    public init() {}

    /// Daily streak over UTC date keys ("2026-07-04"): consecutive days with
    /// a completed daily challenge. A streak survives through yesterday —
    /// today only breaks it once its own challenge expires at midnight.
    public func dailyStreak(
        completedDateKeys: Set<String>,
        today: Date,
    ) -> (current: Int, best: Int) {
        let calendar = EventSeeds.utcCalendar
        let dayNumbers = Set(completedDateKeys
            .compactMap { dayNumber(for: $0, calendar: calendar) })
        guard !dayNumbers.isEmpty else { return (0, 0) }

        let todayNumber = dayNumber(for: EventSeeds.dailyDateKey(for: today), calendar: calendar) ??
            0

        var current = 0
        // The streak anchors on today when completed, otherwise on yesterday.
        var cursor = dayNumbers.contains(todayNumber) ? todayNumber : todayNumber - 1
        while dayNumbers.contains(cursor) {
            current += 1
            cursor -= 1
        }

        var best = 0
        for day in dayNumbers where !dayNumbers.contains(day - 1) {
            var length = 1
            while dayNumbers.contains(day + length) {
                length += 1
            }
            best = max(best, length)
        }
        return (current, best)
    }

    /// Trailing and best win streaks over records ordered by finish time.
    /// A loss or abandonment breaks the streak.
    public func winStreaks(records: [GameRecord]) -> (current: Int, best: Int) {
        let ordered = records.sorted { $0.finishedAt < $1.finishedAt }
        var current = 0
        var best = 0
        for record in ordered {
            if record.outcome == .won {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return (current, best)
    }

    /// Days since the epoch for a "yyyy-MM-dd" key, for gap-free arithmetic.
    private func dayNumber(for dateKey: String, calendar: Calendar) -> Int? {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let date = calendar.date(from: components) else { return nil }
        let epoch = Date(timeIntervalSince1970: 0)
        return calendar.dateComponents([.day], from: epoch, to: date).day
    }
}
