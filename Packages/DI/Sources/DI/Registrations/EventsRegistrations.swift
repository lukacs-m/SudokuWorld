import Data
public import Domain
public import FactoryKit

/// Events wiring: daily challenge, weekly tournament, standings, reminders.
public extension Container {
    var dailyChallengeRepository: Factory<any DailyChallengeRepository> {
        self { SwiftDataDailyChallengeRepository() }
            .singleton
    }

    var notificationScheduler: Factory<any NotificationScheduler> {
        self { UserNotificationsScheduler() }
            .singleton
    }

    var getDailyChallengeUseCase: Factory<any GetDailyChallengeUseCase> {
        self { GetDailyChallenge(dailyChallenges: self.dailyChallengeRepository()) }
    }

    var getWeeklyTournamentUseCase: Factory<any GetWeeklyTournamentUseCase> {
        self { GetWeeklyTournament(dailyChallenges: self.dailyChallengeRepository()) }
    }

    var getStandingsUseCase: Factory<any GetStandingsUseCase> {
        self { GetStandings(gameCenter: self.gameCenterService()) }
    }

    var updateRemindersUseCase: Factory<any UpdateRemindersUseCase> {
        self {
            UpdateReminders(
                scheduler: self.notificationScheduler(),
                dailyChallenges: self.dailyChallengeRepository(),
            )
        }
    }
}
