public import Foundation
public import SwiftUI

/// A live "time remaining" label for event cards, updating once per minute.
public struct CountdownText: View {
    private let deadline: Date

    public init(until deadline: Date) {
        self.deadline = deadline
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(remainingDescription(now: context.date))
                .monospacedDigit()
        }
    }

    private func remainingDescription(now: Date) -> String {
        let remaining = max(0, deadline.timeIntervalSince(now))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours >= 24 {
            let days = hours / 24
            return String(
                format: String(localized: "countdown.daysHours", bundle: .module),
                days,
                hours % 24,
            )
        }
        return String(
            format: String(localized: "countdown.hoursMinutes", bundle: .module),
            hours,
            minutes,
        )
    }
}

/// Formats a play duration as "12:34" or "1:02:03".
public enum DurationFormatter {
    public static func string(for duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
