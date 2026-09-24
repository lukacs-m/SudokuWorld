import Domain
import Foundation
import Model
import SwiftUI

/// Item 9 of the stats plan: one variant in depth. Outcome counts, every
/// difficulty's record, and the variant's own solve-time trend.
struct VariantDetailView: View {
    let variant: SudokuVariant
    let overview: StatsOverview

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let cells = overview.perVariant
            .filter { $0.variant == variant }
            .sorted { $0.difficulty < $1.difficulty }
        ScrollView {
            VStack(spacing: 16) {
                VariantOutcomeGrid(cells: cells)
                VariantDifficultyCard(cells: cells)
                SolveTimeTrendSection(options: [trendOption])
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text(verbatim: moduleString("variant.\(variant.slug)")))
    }

    /// A variant with no win in the last 90 days has no series; an empty one
    /// keeps the card and its empty-state line on screen.
    private var trendOption: TrendSeriesOption {
        TrendSeriesOption(
            id: .variant(variant),
            trend: overview.solveTimeTrendByVariant[variant]
                ?? StatsOverview.SolveTimeTrend(
                    endDay: EventSeeds.utcCalendar.startOfDay(for: Date()),
                    last7Days: [],
                    last30Days: [],
                    last90Days: [],
                ),
        )
    }
}

private struct VariantOutcomeGrid: View {
    let cells: [VariantStats]

    @ScaledMetric(relativeTo: .caption) private var tileMinimum: CGFloat = 100

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 10)],
            spacing: 10,
        ) {
            StatTile("stats.won", value: "\(cells.reduce(0) { $0 + $1.won })")
            StatTile("stats.lost", value: "\(cells.reduce(0) { $0 + $1.lost })")
            StatTile("stats.variant.abandoned", value: "\(cells.reduce(0) { $0 + $1.abandoned })")
        }
    }
}

/// One row per difficulty the variant offers (or once offered): won over
/// played on the left, best and average time on the right, dashes where the
/// tier has no games yet. The counts are motivation and stay free; the times
/// are analysis, so free players get those blurred behind a paywall tap. A
/// variant the player has never finished has no time to hide, so everyone
/// gets the plain card rather than a lock over a column of dashes.
///
/// The paywall is the app router's sheet, above the gate: a purchase made
/// in it flips the branch underneath, and a sheet owned by the locked branch
/// would go with it before the paywall could confirm the purchase.
struct VariantDifficultyCard: View {
    let cells: [VariantStats]

    @Environment(PremiumGate.self) private var premiumGate

    var body: some View {
        if !premiumGate.isPremium, cells.contains(where: { $0.fastestTime != nil }) {
            LockedVariantDifficultyCard(cells: cells)
        } else {
            CardView { VariantDifficultyRows(cells: cells) }
        }
    }
}

/// The lock sits under the rows rather than over them, so the counts it
/// leaves free stay readable. The card opens the paywall wherever it is
/// tapped, but only the lock label is a button: wrapping the whole card in
/// one would merge the rows into a single VoiceOver element and take the
/// per-difficulty counts away from the players this keeps them for.
private struct LockedVariantDifficultyCard: View {
    let cells: [VariantStats]

    @Environment(AppRouter.self) private var router
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // The lock label's Button carries `isButton`; adding it to the card
        // would propagate the trait to every count row, which is not one.
        // swiftlint:disable:next accessibility_trait_for_button
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                VariantDifficultyRows(cells: cells, timesBlurred: true)
                Button {
                    router.presentedSheet = .paywall
                } label: {
                    LockedStatLabel(
                        titleKey: "stats.premium.variantTimes.title",
                        teaseKey: "stats.premium.variantTimes.tease",
                        theme: themeStore.theme(for: colorScheme),
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            router.presentedSheet = .paywall
        }
    }
}

struct VariantDifficultyRows: View {
    let cells: [VariantStats]
    var timesBlurred = false

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("stats.variant.byDifficulty")
            VStack(spacing: 0) {
                ForEach(cells, id: \.difficulty) { cell in
                    VariantDifficultyRow(stats: cell, theme: theme, timesBlurred: timesBlurred)
                    if cell.difficulty != cells.last?.difficulty {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct VariantDifficultyRow: View {
    let stats: VariantStats
    let theme: Theme
    let timesBlurred: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: moduleString("difficulty.\(stats.difficulty.slug)"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                Text(verbatim: stats.played > 0
                    ? wonPlayedString(won: stats.won, played: stats.played)
                    : "-")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            VariantDifficultyTimes(stats: stats, theme: theme, blurred: timesBlurred)
        }
        .padding(.vertical, 8)
    }
}

private struct VariantDifficultyTimes: View {
    let stats: VariantStats
    let theme: Theme
    let blurred: Bool

    var body: some View {
        let times = VStack(alignment: .trailing, spacing: 2) {
            Text(verbatim: stats.fastestTime.map(DurationFormatter.string(for:)) ?? "-")
                .font(.headline)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
            Text(verbatim: stats.averageTime.map(averageTimeString) ?? "-")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
        }
        if blurred, stats.fastestTime != nil {
            times
                .premiumStatBlur(theme: theme)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            times
        }
    }

    private func averageTimeString(_ time: TimeInterval) -> String {
        String(
            format: String(localized: "stats.times.average", bundle: .module),
            DurationFormatter.string(for: time),
        )
    }
}

#Preview("Free") {
    @Previewable @State var router = StatsRouter()
    NavigationStack(path: $router.path) {
        VariantDetailView(variant: .killer, overview: .masteryPreview)
    }
    .environment(router)
    .environment(AppRouter())
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: false))
}

#Preview("Premium") {
    @Previewable @State var router = StatsRouter()
    NavigationStack(path: $router.path) {
        VariantDetailView(variant: .classic, overview: .masteryPreview)
    }
    .environment(router)
    .environment(AppRouter())
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: true))
}
