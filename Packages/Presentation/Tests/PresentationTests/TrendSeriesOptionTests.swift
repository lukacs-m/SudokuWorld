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

    private func options(_ records: [GameRecord]) -> [TrendSeriesOption] {
        TrendSeriesOption.all(from: StatsAggregator().overview(
            records: records,
            dailyCompletionKeys: [],
            today: today,
            firstWeekday: 2,
        ))
    }

    /// The free card draws the last 7 days, so a series whose 20 wins are all
    /// older than a week must not be the one it opens on.
    @Test func theDefaultSeriesIsTheFullestOneInTheWindowOnScreen() {
        let older = (8 ... 27).map { win(.medium, daysAgo: $0) }
        let thisWeek = (0 ... 2).map { win(.easy, daysAgo: $0) }
        let all = options(older + thisWeek)

        #expect(TrendSeriesOption.fullest(of: all, in: \.last7Days)?.id == .classic(.easy))
        #expect(TrendSeriesOption.fullest(of: all, in: \.last30Days)?.id == .classic(.medium))
        #expect(TrendSeriesOption.fullest(of: all, in: \.last90Days)?.id == .classic(.medium))
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
        #expect(TrendSeriesOption.fullest(of: all, in: \.last90Days)?.id == .classic(.medium))
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
