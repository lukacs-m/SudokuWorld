import Model
import SwiftUI

/// Item 7 of the stats plan: mistakes and hints per game plus the perfect
/// solves counter, a blurred preview for free players.
struct AccuracyCard: View {
    let overview: StatsOverview

    @ScaledMetric(relativeTo: .caption) private var tileMinimum: CGFloat = 100

    var body: some View {
        PremiumStatBlurOverlay(
            "stats.premium.perfect.title",
            tease: "stats.premium.perfect.tease",
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("stats.accuracy")
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 10)],
                    spacing: 10,
                ) {
                    StatTile("stats.accuracy.mistakes", value: average(overview.averageMistakes))
                    StatTile("stats.accuracy.hints", value: average(overview.averageHints))
                    StatTile("stats.accuracy.perfect", value: "\(overview.perfectSolves)")
                }
            }
        }
    }

    private func average(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}

#Preview("Free") {
    AccuracyCard(overview: .accuracyPreview)
        .padding()
        .environment(ThemeStore())
        .environment(PremiumGate(isPremium: false))
}

#Preview("Premium") {
    AccuracyCard(overview: .accuracyPreview)
        .padding()
        .environment(ThemeStore())
        .environment(PremiumGate(isPremium: true))
}

private extension StatsOverview {
    static let accuracyPreview = Self(
        totalPlayed: 40,
        totalWon: 31,
        totalLost: 4,
        totalAbandoned: 5,
        gamesToday: 1,
        gamesThisWeek: 6,
        averageMistakes: 1.25,
        averageHints: 0.4,
        perfectSolves: 12,
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
