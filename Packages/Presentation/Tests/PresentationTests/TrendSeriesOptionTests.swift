import Domain
import Foundation
import Model
import Testing

@testable import Presentation

struct TrendSeriesOptionTests {
    private let today = Date(timeIntervalSince1970: 1_783_000_000)

    private func win(_ difficulty: Difficulty, daysAgo: Int) -> GameRecord {
        let finishedAt = today.addingTimeInterval(TimeInterval(-86400 * daysAgo))
        return GameRecord(
            id: UUID(),
            variant: .classic,
            difficulty: difficulty,
            mode: .normal,
            outcome: .won,
            context: .regular,
            duration: 300,
            mistakes: 0,
            hintsUsed: 0,
            usedReveal: false,
            points: 0,
            startedAt: finishedAt.addingTimeInterval(-300),
            finishedAt: finishedAt,
        )
    }

    /// Twenty medium wins between eight and twenty-seven days back, and three
    /// easy ones this week: the shape of a player whose recent week sits on a
    /// different tier than their history.
    private var freeHistory: [TrendSeriesOption] {
        options((8 ... 27).map { win(.medium, daysAgo: $0) }
            + (0 ... 2).map { win(.easy, daysAgo: $0) })
    }

    private func options(_ records: [GameRecord]) -> [TrendSeriesOption] {
        TrendSeriesOption.all(from: StatsAggregator().overview(
            records: records,
            dailyCompletionKeys: [],
            today: today,
            firstWeekday: 2,
        ))
    }

    /// A free card draws seven days but sells the blurred ninety-day one, so
    /// its default is the richest series over ninety days - one win this week
    /// on another tier must not decide which history gets teased.
    @Test func theFreeDefaultSeriesIsTheFullestOverNinetyDays() {
        var selection = TrendSelection()

        selection.seed(from: freeHistory, in: TrendWindows(isPremium: false, window: .days30).seed)

        #expect(selection.id == .classic(.medium))
        #expect(TrendSeriesOption.fullest(of: freeHistory, in: \.last7Days)?.id == .classic(.easy))
    }

    /// The live card keeps the series the tease is selling, so where that
    /// series has no win this week it shows its own empty state instead of
    /// plotting a different line than the card below it.
    @Test func theFreeSevenDayCardIsEmptyWhenTheDefaultHasNoWinsThisWeek() {
        let windows = TrendWindows(isPremium: false, window: .days30)
        var selection = TrendSelection()
        selection.seed(from: freeHistory, in: windows.seed)

        let selected = selection.option(in: freeHistory, window: windows.seed)

        #expect(selected?.trend[keyPath: windows.drawn].isEmpty == true)
        #expect(selected?.trend.last90Days.count == 20)
    }

    /// Premium has one window on screen, so that one drives the default.
    @Test func thePremiumDefaultFollowsTheWindowOnScreen() {
        let all = options((0 ... 2).map { win(.easy, daysAgo: $0) }
            + (31 ... 40).map { win(.medium, daysAgo: $0) })
        var thirtyDays = TrendSelection()
        var ninetyDays = TrendSelection()

        thirtyDays.seed(from: all, in: TrendWindows(isPremium: true, window: .days30).seed)
        ninetyDays.seed(from: all, in: TrendWindows(isPremium: true, window: .days90).seed)

        #expect(thirtyDays.id == .classic(.easy))
        #expect(ninetyDays.id == .classic(.medium))
    }

    /// Nothing won this week: the picker still has to name a series, so the
    /// fullest 90-day one stands in and the chart shows its own empty state.
    @Test func anEmptyWindowFallsBackToTheFullestNinetyDaySeries() {
        let all = options((8 ... 12).map { win(.medium, daysAgo: $0) } + [win(.easy, daysAgo: 20)])
        let fallback = TrendSeriesOption.fullest(of: all, in: \.last7Days)

        #expect(all.allSatisfy { $0.trend.last7Days.isEmpty })
        #expect(fallback?.id == .classic(.medium))
    }

    /// The window picker must not double as a series picker: once the card
    /// has seeded its series, switching 30/90 days keeps that series even
    /// though another one is fuller over the wider window.
    @Test func aWindowToggleKeepsTheSeededSeries() {
        let thisMonth = (0 ... 2).map { win(.easy, daysAgo: $0) }
        let older = (31 ... 40).map { win(.medium, daysAgo: $0) }
        let all = options(thisMonth + older)
        var selection = TrendSelection()

        selection.seed(from: all, in: \.last30Days)
        #expect(selection.id == .classic(.easy))

        selection.seed(from: all, in: \.last90Days)
        #expect(selection.id == .classic(.easy))
        #expect(selection.option(in: all, window: \.last90Days)?.id == .classic(.easy))
        #expect(TrendSeriesOption.fullest(of: all, in: \.last90Days)?.id == .classic(.medium))
    }

    /// A reload drops a series once its last win ages out of the window, and
    /// the stale selection must not leave the picker naming nothing.
    @Test func aSelectionThatNoLongerExistsResolvesToTheDrawnSeries() {
        let all = options((0 ... 2).map { win(.easy, daysAgo: $0) })
        var selection = TrendSelection()
        selection.id = .classic(.master)

        #expect(!all.contains { $0.id == .classic(.master) })
        #expect(selection.option(in: all, window: \.last7Days)?.id == .classic(.easy))
    }

    @Test func noSeriesMeansNoDefault() {
        var selection = TrendSelection()
        selection.seed(from: [], in: \.last7Days)

        #expect(TrendSeriesOption.fullest(of: [], in: \.last7Days) == nil)
        #expect(selection.id == nil)
    }

    /// Classic is covered by its own per-difficulty series, so it must not
    /// also show up as a variant line mixing every tier together.
    @Test func classicIsNotOfferedAsAVariantSeries() {
        let all = options([win(.easy, daysAgo: 1), win(.master, daysAgo: 2)])

        #expect(all.map(\.id) == [.classic(.easy), .classic(.master)])
    }
}
