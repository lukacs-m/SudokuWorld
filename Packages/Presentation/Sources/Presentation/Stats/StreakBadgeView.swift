import Model
import SwiftUI

/// Streak summary row shown on the stats screen.
struct StreakBadgeView: View {
    let streaks: StreakInfo

    var body: some View {
        HStack(spacing: 10) {
            StatTile("stats.streak.daily", value: "\(streaks.currentDailyStreak)")
            StatTile("stats.streak.bestDaily", value: "\(streaks.bestDailyStreak)")
            StatTile("stats.streak.win", value: "\(streaks.currentWinStreak)")
            StatTile("stats.streak.bestWin", value: "\(streaks.bestWinStreak)")
        }
    }
}
