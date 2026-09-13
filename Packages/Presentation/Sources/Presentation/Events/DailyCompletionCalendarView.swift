import Domain
import Foundation
import SwiftUI

/// A month of daily challenges: filled days had a completed challenge. Days
/// are UTC, the daily challenge's own clock, so a filled cell always agrees
/// with the streak. Navigates back as far as the first completed day.
struct DailyCompletionCalendarView: View {
    let completedDayKeys: Set<String>
    let today: Date

    /// Months back from the current month.
    @State private var monthsBack = 0

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    init(completedDayKeys: Set<String>, today: Date = Date()) {
        self.completedDayKeys = completedDayKeys
        self.today = today
    }

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("events.calendar.title")
                CalendarMonthHeader(
                    monthStart: monthStart,
                    canGoBack: monthsBack < earliestMonthsBack,
                    canGoForward: monthsBack > 0,
                    theme: theme,
                ) { step in
                    withAnimation(.snappy) { monthsBack -= step }
                }
                CalendarMonthGrid(
                    monthStart: monthStart,
                    completedDayKeys: completedDayKeys,
                    today: today,
                    calendar: calendar,
                    theme: theme,
                )
            }
        }
    }

    private var calendar: Calendar {
        DailyDayGrid.calendar
    }

    private var currentMonthStart: Date {
        startOfMonth(containing: today)
    }

    private func startOfMonth(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private var monthStart: Date {
        calendar.date(byAdding: .month, value: -monthsBack, to: currentMonthStart)
            ?? currentMonthStart
    }

    /// Date keys sort chronologically, so the smallest is the first completion.
    private var earliestMonthsBack: Int {
        guard let first = completedDayKeys.min(),
              let firstDate = EventSeeds.date(fromDateKey: first)
        else { return 0 }
        let months = calendar.dateComponents(
            [.month],
            from: startOfMonth(containing: firstDate),
            to: currentMonthStart,
        ).month
        return max(months ?? 0, 0)
    }
}

private struct CalendarMonthHeader: View {
    let monthStart: Date
    let canGoBack: Bool
    let canGoForward: Bool
    let theme: Theme
    let onStep: (Int) -> Void

    var body: some View {
        HStack {
            stepButton(
                "events.calendar.previous",
                systemImage: "chevron.left",
                enabled: canGoBack,
            ) {
                onStep(-1)
            }
            Spacer()
            Text(monthStart, format: DailyDayGrid.labelFormat.month(.wide).year())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            stepButton(
                "events.calendar.next",
                systemImage: "chevron.right",
                enabled: canGoForward,
            ) {
                onStep(1)
            }
        }
    }

    private func stepButton(
        _ labelKey: LocalizedStringKey,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? theme.accent : theme.textSecondary.opacity(0.4))
        .disabled(!enabled)
        .accessibilityLabel(Text(labelKey, bundle: .module))
    }
}

private struct CalendarMonthGrid: View {
    let monthStart: Date
    let completedDayKeys: Set<String>
    let today: Date
    let calendar: Calendar
    let theme: Theme

    @ScaledMetric(relativeTo: .subheadline) private var cellSide = DailyDayGrid.cellSide

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 6,
        ) {
            ForEach(weekdaySymbols, id: \.offset) { symbol in
                Text(symbol.element)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            ForEach(0 ..< leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: cellSide)
            }
            ForEach(days, id: \.self) { day in
                DailyDayCell(
                    day: day,
                    isCompleted: completedDayKeys.contains(EventSeeds.dailyDateKey(for: day)),
                    isToday: calendar.isDate(day, inSameDayAs: today),
                    calendar: calendar,
                    theme: theme,
                )
                .frame(maxWidth: .infinity)
                .opacity(day > today ? 0.35 : 1)
            }
        }
    }

    private var weekdaySymbols: [(offset: Int, element: String)] {
        Array(DailyDayGrid.weekdaySymbols(for: calendar).enumerated())
    }

    private var leadingBlanks: Int {
        (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
    }

    private var days: [Date] {
        let count = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        return (0 ..< count).compactMap { calendar.date(byAdding: .day, value: $0, to: monthStart) }
    }
}

#Preview("Two-digit days at AX5") {
    DailyCompletionCalendarView(
        completedDayKeys: ["2026-07-04", "2026-07-18", "2026-07-25"],
        today: EventSeeds.date(fromDateKey: "2026-07-26") ?? Date(),
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
    .environment(ThemeStore())
}
