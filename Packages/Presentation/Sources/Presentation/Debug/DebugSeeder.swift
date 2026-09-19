#if DEBUG
    import DI
    import Domain
    import Foundation
    import Model

    /// Seeds deterministic fake game records and daily completions so
    /// data-driven screens (stats charts, week strip) can be screenshotted
    /// via the `-uiHookSeedStats` launch hook. DEBUG-only.
    @MainActor
    enum DebugSeeder {
        static func seed() async {
            let container = Container.shared
            let records = container.gameRecordRepository()
            let dailies = container.dailyChallengeRepository()
            let now = Date()
            let calendar = Calendar.current

            let variants: [SudokuVariant] = [.classic, .classic, .classic, .killer, .diagonal]
            let difficulties: [Difficulty] = [.easy, .easy, .medium, .medium, .hard, .expert]
            for index in 0 ..< 54 {
                // Four weeks of dense play, then a sparser tail so the 90-day
                // trend differs from the 30-day one.
                let daysAgo = index < 42 ? index % 28 : 30 + (index - 42) * 5
                let started = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
                let duration = TimeInterval(180 + (index * 37) % 900)
                let record = GameRecord(
                    id: UUID(),
                    variant: variants[index % variants.count],
                    difficulty: difficulties[index % difficulties.count],
                    mode: .normal,
                    outcome: index % 5 == 4 ? .lost : .won,
                    context: .regular,
                    duration: duration,
                    mistakes: index % 3,
                    hintsUsed: index % 2,
                    usedReveal: false,
                    points: 0,
                    startedAt: started.addingTimeInterval(-duration),
                    finishedAt: started,
                )
                try? await records.insert(record)
            }

            // A variant played only through a daily slot, long enough ago to
            // have rotated out of the free lineup: its mastery row stays live.
            for offset in [16, 23] {
                let finished = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
                let dateKey = EventSeeds.dailyDateKey(for: finished)
                let record = GameRecord(
                    id: UUID(),
                    variant: .kropki,
                    difficulty: .easy,
                    mode: .normal,
                    outcome: .won,
                    context: .daily(dateKey: dateKey, variant: .kropki),
                    duration: 260,
                    mistakes: 0,
                    hintsUsed: 0,
                    usedReveal: false,
                    points: 0,
                    startedAt: finished.addingTimeInterval(-260),
                    finishedAt: finished,
                )
                try? await records.insert(record)
            }

            // A 5-day daily streak ending today for the week strip, plus
            // scattered earlier days (some on a variant slot) for the calendar.
            let completedOffsets = [0, 1, 2, 3, 4, 7, 9, 12, 13, 20, 26, 33, 41, 42]
            for offset in completedOffsets {
                guard let day = EventSeeds.utcCalendar.date(
                    byAdding: .day, value: -offset, to: now,
                ) else { continue }
                let dateKey = EventSeeds.dailyDateKey(for: day)
                let usesVariantSlot = offset > 0 && offset.isMultiple(of: 3)
                let variant = usesVariantSlot
                    ? EventSeeds.dailySlots(dateKey: dateKey).last?.variant ?? .classic
                    : .classic
                try? await dailies.markCompleted(
                    dateKey: dateKey,
                    variant: variant,
                    duration: 240,
                    at: day,
                )
            }
        }
    }
#endif
