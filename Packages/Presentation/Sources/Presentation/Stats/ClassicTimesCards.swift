import Model
import SwiftUI

/// Item 10 of the stats plan: free players see classic times over the last
/// seven days, with the all-time card behind the premium blur; premium
/// players see all time directly.
struct ClassicTimesCards: View {
    let overview: StatsOverview
    let isPremium: Bool

    var body: some View {
        if isPremium {
            if !overview.classicTimesByDifficulty.isEmpty {
                allTime
            }
        } else {
            if !overview.recentClassicTimesByDifficulty.isEmpty {
                TimesBreakdownView(
                    title: String(
                        format: String(localized: "stats.chart.times.recent", bundle: .module),
                        StatsOverview.recentHistoryDays,
                    ),
                    entries: overview.recentClassicTimesByDifficulty,
                )
            }
            if !overview.classicTimesByDifficulty.isEmpty {
                PremiumStatBlurOverlay(
                    "stats.premium.allTimeTimes.title",
                    tease: "stats.premium.allTimeTimes.tease",
                ) {
                    allTime
                }
            }
        }
    }

    private var allTime: some View {
        TimesBreakdownView(
            title: moduleString("stats.chart.times"),
            entries: overview.classicTimesByDifficulty,
        )
    }
}
