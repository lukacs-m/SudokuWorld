import Foundation
import SwiftUI

/// One day of a daily-challenge grid, shared by the events week strip and the
/// month calendar so both encode the same state the same way: a completed day
/// is a filled accent circle, today wears an accent ring, and a completed today
/// gets both. The cell fills the slot its grid gives it and stays square, so it
/// can never overhang a neighbour; at accessibility text sizes the digits scale
/// down inside that slot instead.
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
        let date = day.formatted(DailyDayGrid.labelFormat.month(.wide).day())
        guard isCompleted else { return Text(verbatim: date) }
        let completed = String(localized: "events.calendar.completed", bundle: .module)
        return Text(verbatim: "\(date), \(completed)")
    }
}
