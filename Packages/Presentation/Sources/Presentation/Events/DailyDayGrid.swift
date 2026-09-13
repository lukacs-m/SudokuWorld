import Domain
import Foundation

/// The display side of the daily challenge's UTC clock. Every day grid and day
/// label on the events screens derives from here, so the week strip, the month
/// calendar and the archive all name the same day as the streak does.
enum DailyDayGrid {
    /// UTC days, in the device's language and laid out with its first weekday.
    /// A bare `Calendar(identifier:)` carries the fixed root locale, so the
    /// locale has to be set explicitly for the weekday symbols to localize.
    static var calendar: Calendar {
        var utc = EventSeeds.utcCalendar
        utc.locale = .current
        utc.firstWeekday = firstWeekday
        return utc
    }

    /// Where the week starts, for the grids and for the "this week" counter.
    static var firstWeekday: Int {
        Calendar.current.firstWeekday
    }

    /// Days in this grid are UTC day starts, so their labels must format in UTC
    /// too - the device time zone would shift them by one day either way.
    static var labelFormat: Date.FormatStyle {
        Date.FormatStyle(timeZone: .gmt)
    }

    /// The seven UTC days of the week containing `date`.
    static func weekDays(containing date: Date) -> [Date] {
        let grid = calendar
        let today = grid.startOfDay(for: date)
        let delta = (grid.component(.weekday, from: today) - grid.firstWeekday + 7) % 7
        let start = grid.date(byAdding: .day, value: -delta, to: today) ?? today
        return (0 ..< 7).compactMap { grid.date(byAdding: .day, value: $0, to: start) }
    }

    /// Very short weekday symbols rotated to start on the calendar's first
    /// weekday. Index 0 of the symbol array is Sunday in every locale.
    static func weekdaySymbols(for calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
