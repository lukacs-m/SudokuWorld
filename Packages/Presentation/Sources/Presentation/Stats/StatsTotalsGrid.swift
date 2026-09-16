import Model
import SwiftUI

/// The stats header: three tiles per row at normal text sizes, dropping to
/// two or one as Dynamic Type grows the captions.
struct StatsTotalsGrid: View {
    let overview: StatsOverview

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
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
