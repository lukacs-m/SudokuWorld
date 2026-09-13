import Model
import SwiftUI

/// The stats header: three tiles per row, since six captions in one row
/// truncate on small phones.
struct StatsTotalsGrid: View {
    let overview: StatsOverview

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
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
