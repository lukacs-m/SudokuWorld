import Model
import SwiftUI

/// The stats header. The column count follows a minimum tile width that scales
/// with the caption text, so three tiles per row at normal sizes becomes two
/// and then one as Dynamic Type grows and the captions need the room.
struct StatsTotalsGrid: View {
    let overview: StatsOverview

    @ScaledMetric(relativeTo: .caption) private var tileMinimum: CGFloat = 100

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 10)],
            spacing: 10,
        ) {
            StatTile("stats.today", value: "\(overview.gamesToday)")
            StatTile("stats.thisWeek", value: "\(overview.gamesThisWeek)")
            StatTile("stats.played", value: "\(overview.totalPlayed)")
            StatTile("stats.winRate", value: "\(Int(overview.winRate * 100))%")
            StatTile("stats.won", value: "\(overview.totalWon)")
            StatTile("stats.lost", value: "\(overview.totalLost)")
        }
    }
}

#Preview("Default") {
    StatsTotalsGrid(overview: .preview)
        .padding(16)
        .environment(ThemeStore())
}

/// The widest caption ("Cette semaine") at the largest text size: the grid has
/// to drop to fewer columns rather than truncate it.
#Preview("French · AX5") {
    StatsTotalsGrid(overview: .preview)
        .padding(16)
        .environment(\.locale, Locale(identifier: "fr"))
        .environment(\.dynamicTypeSize, .accessibility5)
        .environment(ThemeStore())
}

private extension StatsOverview {
    /// Every tile at its widest: a five-digit count and a 100% win rate.
    static let preview = Self(
        totalPlayed: 12345,
        totalWon: 12345,
        totalLost: 0,
        totalAbandoned: 0,
        gamesToday: 8,
        gamesThisWeek: 41,
        averageMistakes: 0,
        averageHints: 0,
        perfectSolves: 0,
        streaks: .zero,
        perVariant: [],
        gamesPerDay: [],
        classicWinRateByDifficulty: [],
        classicTimesByDifficulty: [],
        classicSolveTimeTrendByDifficulty: [:],
        solveTimeTrendByVariant: [:],
        variantShares: [],
    )
}
