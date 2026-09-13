import Domain
import Foundation
import Testing

@testable import Presentation

struct DailyDayGridTests {
    /// 00:30 on 5 July in Paris is still 4 July in UTC, so the daily challenge
    /// completed then belongs to 4 July. The week strip, the month calendar and
    /// the archive all have to name that same day.
    @Test func aUTCPlusTwoCompletionLandsOnTheSameDayInEveryGrid() throws {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        let completion = try #require(paris.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 5,
            hour: 0,
            minute: 30,
        )))
        let key = EventSeeds.dailyDateKey(for: completion)
        #expect(key == "2026-07-04")

        let grid = DailyDayGrid.calendar

        // Week strip: the cell the completion key fills is the one labelled 4.
        let stripDay = try #require(
            DailyDayGrid.weekDays(containing: completion)
                .first { EventSeeds.dailyDateKey(for: $0) == key },
        )
        #expect(grid.component(.day, from: stripDay) == 4)
        #expect(grid.isDate(stripDay, inSameDayAs: completion))

        // Month calendar: same day, reached from the key instead of the clock.
        let calendarDay = try #require(EventSeeds.date(fromDateKey: key))
        #expect(grid.isDate(calendarDay, inSameDayAs: stripDay))
        #expect(grid.component(.day, from: calendarDay) == 4)

        // Archive: the label for that key reads 4 July, not 3 or 5.
        let label = calendarDay.formatted(
            DailyDayGrid.labelFormat
                .weekday(.wide)
                .month(.wide)
                .day()
                .locale(Locale(identifier: "en_US")),
        )
        #expect(label == "Saturday, July 4")
    }

    /// The header row must read in the calendar's own language - a bare
    /// `Calendar(identifier:)` carries the fixed root locale and stays English.
    @Test func weekdaySymbolsFollowTheCalendarLocaleAndStartOnItsFirstWeekday() {
        #expect(DailyDayGrid.calendar.locale == .current)

        var french = DailyDayGrid.calendar
        french.locale = Locale(identifier: "fr_FR")
        french.firstWeekday = 2
        #expect(DailyDayGrid.weekdaySymbols(for: french) == ["L", "M", "M", "J", "V", "S", "D"])

        var english = DailyDayGrid.calendar
        english.locale = Locale(identifier: "en_US")
        english.firstWeekday = 1
        #expect(DailyDayGrid.weekdaySymbols(for: english) == ["S", "M", "T", "W", "T", "F", "S"])
    }
}
