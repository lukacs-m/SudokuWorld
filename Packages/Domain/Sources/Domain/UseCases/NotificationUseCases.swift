public import Foundation
public import Model

/// Applies the player's reminder preferences: requests permission when
/// needed and (re)schedules the daily-challenge and streak-saver reminders.
/// Returns whether notifications are authorized afterward.
public protocol UpdateRemindersUseCase: Sendable {
    func callAsFunction(
        preferences: NotificationPreferences,
        copy: ReminderCopy,
        now: Date,
    ) async -> Bool
}

public struct UpdateReminders: UpdateRemindersUseCase {
    private let scheduler: any NotificationScheduler
    private let dailyChallenges: any DailyChallengeRepository
    private let streaks = StreakCalculator()

    public init(
        scheduler: any NotificationScheduler,
        dailyChallenges: any DailyChallengeRepository,
    ) {
        self.scheduler = scheduler
        self.dailyChallenges = dailyChallenges
    }

    public func callAsFunction(
        preferences: NotificationPreferences,
        copy: ReminderCopy,
        now: Date,
    ) async -> Bool {
        guard preferences.dailyReminderEnabled || preferences.streakReminderEnabled else {
            await scheduler.cancelAllReminders()
            return true
        }
        guard await scheduler.requestAuthorization() else { return false }

        let completedKeys = await (try? dailyChallenges.completedDays()) ?? []
        let streak = streaks.dailyStreak(completedDateKeys: completedKeys, today: now)
        let todayDone = completedKeys.contains(EventSeeds.dailyDateKey(for: now))
        await scheduler.updateReminders(
            preferences: preferences,
            copy: copy,
            streakAtRisk: streak.current > 0 && !todayDone,
        )
        return true
    }
}
