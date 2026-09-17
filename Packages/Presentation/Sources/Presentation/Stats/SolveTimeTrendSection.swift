import Charts
import Domain
import Foundation
import Model
import SwiftUI

/// One line the trend card can plot: a classic difficulty or a variant.
struct TrendSeriesOption: Identifiable, Equatable {
    enum Series: Hashable {
        case classic(Difficulty)
        case variant(SudokuVariant)
    }

    let id: Series
    let trend: StatsOverview.SolveTimeTrend

    var label: String {
        switch id {
        case let .classic(difficulty):
            "\(moduleString("variant.classic")) · \(moduleString("difficulty.\(difficulty.slug)"))"
        case let .variant(variant):
            moduleString("variant.\(variant.slug)")
        }
    }

    /// Classic per difficulty first, then every other variant with a win in
    /// the last 90 days, in the app's own order. Classic is left out of the
    /// variant list: its difficulties already cover it, and a series mixing
    /// an easy solve with a master one is not comparable.
    static func all(from overview: StatsOverview) -> [Self] {
        let classic = Difficulty.allCases.compactMap { difficulty in
            overview.classicSolveTimeTrendByDifficulty[difficulty]
                .map { Self(id: .classic(difficulty), trend: $0) }
        }
        let variants = SudokuVariant.allCases
            .filter { $0 != .classic }
            .compactMap { variant in
                overview.solveTimeTrendByVariant[variant]
                    .map { Self(id: .variant(variant), trend: $0) }
            }
        return classic + variants
    }
}

extension TrendSeriesOption {
    /// One of a trend's windows, as the card draws it.
    typealias Window = KeyPath<StatsOverview.SolveTimeTrend, [StatsOverview.TrendPoint]>

    /// The series an unset picker names: the fullest one in the window on
    /// screen, so the card never opens on an empty chart while another series
    /// has wins to show. When no series has a point in that window it falls
    /// back to the fullest 90-day series, so the picker still names a real
    /// series above the chart's own empty state.
    static func fullest(of options: [Self], in window: Window) -> Self? {
        mostPoints(of: options, in: window) ?? mostPoints(of: options, in: \.last90Days)
    }

    private static func mostPoints(of options: [Self], in window: Window) -> Self? {
        options
            .filter { !$0.trend[keyPath: window].isEmpty }
            .max { $0.trend[keyPath: window].count < $1.trend[keyPath: window].count }
    }
}

/// The card's series choice. Seeded from the window on screen the first time
/// the card appears and then left alone, so switching the window keeps the
/// line the player is reading instead of swapping it for a fuller one.
struct TrendSelection: Equatable {
    var id: TrendSeriesOption.Series?

    mutating func seed(from options: [TrendSeriesOption], in window: TrendSeriesOption.Window) {
        guard id == nil else { return }
        id = TrendSeriesOption.fullest(of: options, in: window)?.id
    }
}

enum TrendWindow: Int, CaseIterable, Identifiable {
    case days30 = 30
    case days90 = 90

    var id: Int {
        rawValue
    }
}

/// Item 6 of the stats plan: average solve time over 30 or 90 days. Premium
/// players get the full window in one card. Free players get the last 7 days
/// live, with the picked window blurred right underneath as the paywall tease.
struct SolveTimeTrendSection: View {
    let options: [TrendSeriesOption]

    @State private var window: TrendWindow = .days30
    @State private var selection = TrendSelection()

    @Environment(PremiumGate.self) private var premiumGate

    var body: some View {
        let selected = options.first { $0.id == selection.id } ?? defaultOption
        let drawn = selected?.trend[keyPath: displayedWindow] ?? []
        Group {
            if premiumGate.isPremium {
                CardView {
                    TrendCardContent(
                        "stats.trend.title",
                        points: drawn,
                        days: window.rawValue,
                        endDay: selected?.trend.endDay,
                    ) {
                        TrendControls(
                            options: options,
                            window: $window,
                            selectedID: seriesSelection,
                        )
                    }
                }
            } else {
                CardView {
                    TrendCardContent(
                        "stats.trend.free.title",
                        points: drawn,
                        days: 7,
                        endDay: selected?.trend.endDay,
                    ) {
                        TrendSeriesPicker(options: options, selectedID: seriesSelection)
                    }
                }
                // The tease is pinned to the widest window: a picker here would
                // change a chart the free player cannot read anyway.
                PremiumStatBlurOverlay(
                    "stats.premium.trend.title \(TrendWindow.days90.rawValue)",
                    tease: "stats.premium.trend.tease",
                ) {
                    TrendCardContent(
                        "stats.trend.title",
                        points: selected?.trend.last90Days ?? [],
                        days: TrendWindow.days90.rawValue,
                        endDay: selected?.trend.endDay,
                    ) {
                        EmptyView()
                    }
                }
            }
        }
        .onAppear { selection.seed(from: options, in: displayedWindow) }
    }

    /// The window the live card draws, so the default series is picked from
    /// the points that are actually on screen.
    private var displayedWindow: TrendSeriesOption.Window {
        guard premiumGate.isPremium else { return \.last7Days }
        return switch window {
        case .days30: \.last30Days
        case .days90: \.last90Days
        }
    }

    private var defaultOption: TrendSeriesOption? {
        TrendSeriesOption.fullest(of: options, in: displayedWindow)
    }

    /// The picker needs a concrete selection to show its label, so an unset
    /// state reads as the default series.
    private var seriesSelection: Binding<TrendSeriesOption.Series?> {
        Binding(
            get: { selection.id ?? defaultOption?.id },
            set: { selection.id = $0 },
        )
    }
}

/// The premium window picker, above the series picker.
private struct TrendControls: View {
    let options: [TrendSeriesOption]
    @Binding var window: TrendWindow
    @Binding var selectedID: TrendSeriesOption.Series?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(selection: $window) {
                ForEach(TrendWindow.allCases) { window in
                    Text("stats.trend.window \(window.rawValue)", bundle: .module).tag(window)
                }
            } label: {
                Text("stats.trend.window.label", bundle: .module)
            }
            .pickerStyle(.segmented)

            TrendSeriesPicker(options: options, selectedID: $selectedID)
        }
    }
}

/// Shown only when there is more than one line to choose from (the deep dive
/// pins its variant).
private struct TrendSeriesPicker: View {
    let options: [TrendSeriesOption]
    @Binding var selectedID: TrendSeriesOption.Series?

    var body: some View {
        if options.count > 1 {
            Picker(selection: $selectedID) {
                ForEach(options) { option in
                    Text(verbatim: option.label).tag(Optional(option.id))
                }
            } label: {
                Text("stats.trend.series", bundle: .module)
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

/// Title, optional controls and the chart, without the card, so the free tier
/// can put the same content inside a `PremiumStatBlurOverlay`.
struct TrendCardContent<Controls: View>: View {
    private let titleKey: LocalizedStringKey
    private let points: [StatsOverview.TrendPoint]
    private let days: Int
    private let endDay: Date?
    private let controls: Controls

    init(
        _ titleKey: LocalizedStringKey,
        points: [StatsOverview.TrendPoint],
        days: Int,
        endDay: Date?,
        @ViewBuilder controls: () -> Controls,
    ) {
        self.titleKey = titleKey
        self.points = points
        self.days = days
        self.endDay = endDay
        self.controls = controls()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(titleKey)
            controls
            SolveTimeTrendChart(points: points, days: days, endDay: endDay)
        }
    }
}

/// The line itself. The x domain is always the whole window, so one or two
/// wins sit where they happened instead of stretching across the card, and
/// the height follows the body text so the chart grows with Dynamic Type.
struct SolveTimeTrendChart: View {
    let points: [StatsOverview.TrendPoint]
    let days: Int
    /// The UTC day the points were bucketed against. A live `Date()` would
    /// drift past it once midnight passes with the screen open, clipping the
    /// oldest point out of the domain.
    let endDay: Date?

    private let utc = EventSeeds.utcCalendar

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 170

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        if points.isEmpty {
            Text("stats.trend.empty", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: height)
        } else {
            chart(theme: theme)
        }
    }

    private func chart(theme: Theme) -> some View {
        Chart(points) { point in
            LineMark(
                x: .value("Day", point.day, unit: .day, calendar: utc),
                y: .value("Time", point.averageTime),
            )
            .foregroundStyle(theme.accent)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            PointMark(
                x: .value("Day", point.day, unit: .day, calendar: utc),
                y: .value("Time", point.averageTime),
            )
            .foregroundStyle(theme.accent)
            .symbolSize(28)
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0 ... yTicks[2])
        .chartXAxis {
            AxisMarks(values: xTicks) {
                AxisValueLabel(
                    format: DailyDayGrid.labelFormat.day().month(.abbreviated),
                )
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(theme.gridLine)
                AxisValueLabel {
                    if let seconds = value.as(TimeInterval.self) {
                        Text(DurationFormatter.string(for: seconds))
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var startOfWindow: Date {
        let end = endDay ?? utc.startOfDay(for: Date())
        return utc.date(byAdding: .day, value: 1 - days, to: end) ?? end
    }

    /// The window's UTC days, padded half a day per side like the activity chart.
    private var domain: ClosedRange<Date> {
        let halfDay: TimeInterval = 43200
        let end = utc.date(byAdding: .day, value: days - 1, to: startOfWindow) ?? startOfWindow
        return startOfWindow.addingTimeInterval(-halfDay) ... end.addingTimeInterval(halfDay)
    }

    /// About four ticks, kept off both plot edges so no label is clipped
    /// (an automatic axis lands its last label on the trailing edge).
    private var xTicks: [Date] {
        let step = max(2, days / 4)
        return stride(from: 1, to: days - 1, by: step).compactMap { offset in
            utc.date(byAdding: .day, value: offset, to: startOfWindow)
        }
    }

    /// Zero, half and a whole-minute ceiling above the slowest day, so the
    /// axis reads as clean times even for a single point.
    private var yTicks: [TimeInterval] {
        let slowest = points.map(\.averageTime).max() ?? 60
        let top = max(60, (slowest * 1.15 / 60).rounded(.up) * 60)
        return [0, top / 2, top]
    }
}

#Preview("Free · sparse") {
    ScrollView {
        VStack(spacing: 16) {
            SolveTimeTrendSection(options: PreviewData.options)
        }
        .padding()
    }
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: false))
}

#Preview("Premium") {
    ScrollView {
        VStack(spacing: 16) {
            SolveTimeTrendSection(options: PreviewData.options)
        }
        .padding()
    }
    .environment(ThemeStore())
    .environment(PremiumGate(isPremium: true))
}

#Preview("Premium · no wins") {
    SolveTimeTrendSection(options: [])
        .padding()
        .environment(ThemeStore())
        .environment(PremiumGate(isPremium: true))
}

private enum PreviewData {
    static let options: [TrendSeriesOption] = {
        let today = EventSeeds.utcCalendar.startOfDay(for: Date())
        let offsets: [Int] = [40, 12, 3, 2, 0]
        let points: [StatsOverview.TrendPoint] = offsets.map { offset in
            let day = today.addingTimeInterval(TimeInterval(-86400 * offset))
            return StatsOverview.TrendPoint(day: day, averageTime: TimeInterval(240 + offset * 9))
        }
        let weekAgo = today.addingTimeInterval(-6 * 86400)
        let monthAgo = today.addingTimeInterval(-29 * 86400)
        let trend = StatsOverview.SolveTimeTrend(
            endDay: today,
            last7Days: points.filter { $0.day >= weekAgo },
            last30Days: points.filter { $0.day >= monthAgo },
            last90Days: points,
        )
        return [
            TrendSeriesOption(id: .classic(.medium), trend: trend),
            TrendSeriesOption(id: .variant(.killer), trend: trend),
        ]
    }()
}
