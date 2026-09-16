import Foundation
import SwiftUI

/// One day of a daily-challenge grid, shared by the events week strip and the
/// month calendar so both encode the same state the same way. A completed day
/// is an accent dot inset from the slot edge, with a white digit; today is an
/// accent ring on the slot edge, with an accent digit. A completed today is
/// both, concentric, and the inset leaves a card-coloured gap between the dot
/// and the ring so the ring still reads over the fill. The cell fills the slot
/// its grid gives it and stays square, so it can never overhang a neighbour; at
/// accessibility text sizes the digits scale down inside that slot instead.
struct DailyDayCell: View {
    let day: Date
    let isCompleted: Bool
    let isToday: Bool
    let calendar: Calendar
    let theme: Theme

    var body: some View {
        Text(verbatim: "\(calendar.component(.day, from: day))")
            .font(.subheadline.weight(isToday ? .bold : .medium))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(numberColor)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(isCompleted ? theme.accent : .clear, in: Circle().inset(by: 3))
            .overlay {
                if isToday {
                    Circle().strokeBorder(theme.accent, lineWidth: 1.5)
                }
            }
            .accessibilityLabel(accessibilityLabel)
    }

    private var numberColor: Color {
        if isCompleted {
            return .white
        }
        return isToday ? theme.accent : theme.textPrimary
    }

    private var accessibilityLabel: Text {
        var parts = [day.formatted(DailyDayGrid.labelFormat.month(.wide).day())]
        if isToday {
            parts.append(String(localized: "events.calendar.today", bundle: .module))
        }
        if isCompleted {
            parts.append(String(localized: "events.calendar.completed", bundle: .module))
        }
        return Text(verbatim: parts.joined(separator: ", "))
    }
}

#Preview("Light") {
    DayCellStates(colorScheme: .light)
}

#Preview("Dark") {
    DayCellStates(colorScheme: .dark)
}

/// The four states side by side; the first two are the pair that has to stay
/// distinguishable once today's challenge is done.
private struct DayCellStates: View {
    let colorScheme: ColorScheme

    var body: some View {
        let theme = ThemeStore().theme(for: colorScheme)
        HStack(spacing: 4) {
            cell(isCompleted: true, isToday: true, theme: theme)
            cell(isCompleted: false, isToday: true, theme: theme)
            cell(isCompleted: true, isToday: false, theme: theme)
            cell(isCompleted: false, isToday: false, theme: theme)
        }
        .frame(width: 176)
        .padding(18)
        .background(theme.cardBackground)
        .preferredColorScheme(colorScheme)
    }

    private var previewDay: DateComponents {
        DateComponents(year: 2026, month: 9, day: 16)
    }

    private func cell(isCompleted: Bool, isToday: Bool, theme: Theme) -> some View {
        DailyDayCell(
            day: DailyDayGrid.calendar.date(from: previewDay) ?? Date(),
            isCompleted: isCompleted,
            isToday: isToday,
            calendar: DailyDayGrid.calendar,
            theme: theme,
        )
    }
}
