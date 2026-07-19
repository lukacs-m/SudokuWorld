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
            for index in 0 ..< 42 {
                let daysAgo = index % 28
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

            // A 5-day daily streak ending today, for the week strip.
            for offset in 0 ..< 5 {
                guard let day = EventSeeds.utcCalendar.date(
                    byAdding: .day, value: -offset, to: now,
                ) else { continue }
                try? await dailies.markCompleted(
                    dateKey: EventSeeds.dailyDateKey(for: day),
                    duration: 240,
                    at: day,
                )
            }
        }
    }
#endif
