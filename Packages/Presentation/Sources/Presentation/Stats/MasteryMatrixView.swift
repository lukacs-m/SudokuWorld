import Foundation
import Model
import SwiftUI

/// Item 8 of the stats plan: variant × difficulty, each cell with solved count,
/// best time and a perfect-solve star. Premium players see every row; free
/// players keep the variants they have played and get the rest blurred.
struct MasteryMatrixView: View {
    let overview: StatsOverview

    @Environment(PremiumGate.self) private var premiumGate
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        let layout = MasteryMatrixLayout(overview: overview)
        ScrollView {
            VStack(spacing: 16) {
                if premiumGate.isPremium {
                    CardView {
                        MasteryGrid(rows: layout.rows, overview: overview, opensDetail: true)
                    }
                } else {
                    if !layout.touched.isEmpty {
                        CardView {
                            MasteryGrid(rows: layout.touched, overview: overview, opensDetail: true)
                        }
                    }
                    if !layout.locked.isEmpty {
                        PremiumStatBlurOverlay(
                            "stats.premium.mastery.title \(layout.locked.count)",
                            tease: "stats.premium.mastery.tease",
                            labelAlignment: .top,
                        ) {
                            MasteryGrid(rows: layout.locked, overview: overview, opensDetail: false)
                        }
                    }
                }
                Label {
                    Text("stats.mastery.legend.perfect", bundle: .module)
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(theme.gold)
                }
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text("stats.mastery.title", bundle: .module))
    }
}

/// The header row and one row per variant. Columns are fixed widths that
/// scale with the text, so rows align without a `Grid`; the strip fills the
/// card at normal sizes and scrolls sideways once the columns outgrow it.
private struct MasteryGrid: View {
    let rows: [MasteryRow]
    let overview: StatsOverview
    let opensDetail: Bool

    @ScaledMetric(relativeTo: .subheadline) private var nameWidth: CGFloat = 92
    @ScaledMetric(relativeTo: .caption2) private var cellWidth: CGFloat = 36
    private let spacing: CGFloat = 1

    var body: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                MasteryHeaderRow(nameWidth: nameWidth, cellWidth: cellWidth, spacing: spacing)
                ForEach(rows) { row in
                    Divider()
                    if opensDetail {
                        NavigationLink {
                            VariantDetailView(variant: row.variant, overview: overview)
                        } label: {
                            MasteryRowView(
                                row: row,
                                nameWidth: nameWidth,
                                cellWidth: cellWidth,
                                spacing: spacing,
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        MasteryRowView(
                            row: row,
                            nameWidth: nameWidth,
                            cellWidth: cellWidth,
                            spacing: spacing,
                        )
                    }
                }
            }
            .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                max(width, minimumWidth)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var minimumWidth: CGFloat {
        nameWidth + CGFloat(Difficulty.allCases.count) * (cellWidth + spacing)
    }
}

private struct MasteryHeaderRow: View {
    let nameWidth: CGFloat
    let cellWidth: CGFloat
    let spacing: CGFloat

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        HStack(spacing: spacing) {
            Color.clear
                .frame(width: nameWidth, height: 1)
            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                Text(verbatim: moduleString("difficulty.\(difficulty.slug)"))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(theme.textSecondary)
                    .frame(minWidth: cellWidth, maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
        .accessibilityHidden(true)
    }
}

private struct MasteryRowView: View {
    let row: MasteryRow
    let nameWidth: CGFloat
    let cellWidth: CGFloat
    let spacing: CGFloat

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        HStack(spacing: spacing) {
            Text(verbatim: moduleString("variant.\(row.variant.slug)"))
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(theme.textPrimary)
                .frame(width: nameWidth, alignment: .leading)
            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                MasteryCellView(
                    difficulty: difficulty,
                    cell: row.cell(for: difficulty),
                    theme: theme,
                )
                .frame(minWidth: cellWidth, maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}

/// Solved count over best time; a dash where the variant has no games (or
/// does not offer the tier), a gold star once a perfect solve is in.
private struct MasteryCellView: View {
    let difficulty: Difficulty
    let cell: VariantStats?
    let theme: Theme

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(verbatim: solved)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                if cell?.hasPerfectSolve == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.gold)
                }
            }
            Text(verbatim: best)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
    }

    private var solved: String {
        guard let cell, cell.played > 0 else { return "-" }
        return "\(cell.won)"
    }

    private var best: String {
        guard let fastest = cell?.fastestTime else { return "-" }
        return DurationFormatter.string(for: fastest)
    }

    private var accessibilityLabel: String {
        let name = moduleString("difficulty.\(difficulty.slug)")
        guard let cell, cell.played > 0 else {
            return "\(name): \(moduleString("stats.mastery.cell.none"))"
        }
        let solvedCount = String(
            localized: "stats.mastery.cell.solved \(cell.won)",
            bundle: .module,
        )
        var parts = [solvedCount]
        if let fastest = cell.fastestTime {
            parts.append(bestTimeString(fastest))
        }
        if cell.hasPerfectSolve {
            parts.append(moduleString("stats.mastery.legend.perfect"))
        }
        return "\(name): \(parts.joined(separator: ", "))"
    }
}

#Preview("Free") {
    NavigationStack {
        MasteryMatrixView(overview: .masteryPreview)
    }
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: false))
}

#Preview("Premium · AX3") {
    NavigationStack {
        MasteryMatrixView(overview: .masteryPreview)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: true))
}

extension StatsOverview {
    /// Classic played on every tier, killer on two, everything else untouched.
    static let masteryPreview: Self = {
        var cells: [VariantStats] = []
        for variant in SudokuVariant.allCases {
            for difficulty in variant.offeredDifficulties {
                let played = variant == .classic ? 4 :
                    (variant == .killer && difficulty <= .easy ? 2 : 0)
                cells.append(VariantStats(
                    variant: variant,
                    difficulty: difficulty,
                    played: played,
                    won: played > 0 ? played - 1 : 0,
                    lost: played > 0 ? 1 : 0,
                    abandoned: 0,
                    currentWinStreak: 0,
                    bestWinStreak: 0,
                    fastestTime: played > 0 ? TimeInterval(200 + difficulty.rank * 140) : nil,
                    averageTime: played > 0 ? TimeInterval(260 + difficulty.rank * 160) : nil,
                    perfectSolves: difficulty == .easy && played > 0 ? 1 : 0,
                ))
            }
        }
        return Self(
            totalPlayed: 28,
            totalWon: 22,
            totalLost: 6,
            totalAbandoned: 0,
            gamesToday: 0,
            gamesThisWeek: 0,
            averageMistakes: 0,
            averageHints: 0,
            perfectSolves: 2,
            streaks: .zero,
            perVariant: cells,
            gamesPerDay: [],
            classicWinRateByDifficulty: [],
            classicTimesByDifficulty: [],
            classicSolveTimeTrendByDifficulty: [:],
            solveTimeTrendByVariant: [:],
            variantShares: [],
        )
    }()
}
