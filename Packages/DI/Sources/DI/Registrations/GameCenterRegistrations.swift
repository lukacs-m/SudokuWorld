import Data
public import Domain
public import FactoryKit

/// Game Center wiring.
public extension Container {
    var gameCenterService: Factory<any GameCenterService> {
        self { GameKitGameCenterService() }
            .singleton
    }

    var authenticateGameCenterUseCase: Factory<any AuthenticateGameCenterUseCase> {
        self { AuthenticateGameCenter(gameCenter: self.gameCenterService()) }
    }

    var observeGameCenterAuthUseCase: Factory<any ObserveGameCenterAuthUseCase> {
        self { ObserveGameCenterAuth(gameCenter: self.gameCenterService()) }
    }

    var resetAchievementsUseCase: Factory<any ResetAchievementsUseCase> {
        self { ResetAchievements(gameCenter: self.gameCenterService()) }
    }
}
