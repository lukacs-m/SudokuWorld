public import Foundation

/// A day's three shared challenges: classic plus two rotating variants.
/// Derived from the calendar alone, so every player worldwide sees the
/// identical lineup and boards.
public struct DailyLineup: Equatable, Sendable {
    public struct Slot: Equatable, Sendable {
        public let variant: SudokuVariant
        public let difficulty: Difficulty
        /// Best completion time for this slot, nil while unsolved.
        public let completionTime: TimeInterval?

        public var isCompleted: Bool {
            completionTime != nil
        }

        public init(
            variant: SudokuVariant,
            difficulty: Difficulty,
            completionTime: TimeInterval?,
        ) {
            self.variant = variant
            self.difficulty = difficulty
            self.completionTime = completionTime
        }
    }

    /// UTC calendar key, e.g. "2026-07-04".
    public let dateKey: String
    /// When this lineup rotates out (the day's UTC midnight end).
    public let endsAt: Date
    /// Classic first, then the accessible and complex rotation slots.
    public let slots: [Slot]

    public init(dateKey: String, endsAt: Date, slots: [Slot]) {
        self.dateKey = dateKey
        self.endsAt = endsAt
        self.slots = slots
    }
}
