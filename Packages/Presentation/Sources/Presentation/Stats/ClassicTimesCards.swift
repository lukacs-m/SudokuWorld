import Model
import SwiftUI

/// Item 4 of the stats plan: the best and average classic time per difficulty
/// over all history, free for everyone.
struct ClassicTimesCards: View {
    let overview: StatsOverview

    var body: some View {
        if !overview.classicTimesByDifficulty.isEmpty {
            TimesBreakdownView(
                title: moduleString("stats.chart.times"),
                entries: overview.classicTimesByDifficulty,
            )
        }
    }
}
