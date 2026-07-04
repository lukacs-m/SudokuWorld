import Data
public import Domain
public import FactoryKit

/// Core gameplay wiring: persistence for games, the game lifecycle, and hints.
public extension Container {
    var savedGameRepository: Factory<any SavedGameRepository> {
        self { SwiftDataSavedGameRepository() }
            .singleton
    }

    var gameRecordRepository: Factory<any GameRecordRepository> {
        self { SwiftDataGameRecordRepository() }
            .singleton
    }

    var startGameUseCase: Factory<any StartGameUseCase> {
        self { StartGame(savedGames: self.savedGameRepository()) }
    }

    var resumeGameUseCase: Factory<any ResumeGameUseCase> {
        self { ResumeGame(savedGames: self.savedGameRepository()) }
    }

    var saveGameUseCase: Factory<any SaveGameUseCase> {
        self { SaveGame(savedGames: self.savedGameRepository()) }
    }

    var abandonGameUseCase: Factory<any AbandonGameUseCase> {
        self {
            AbandonGame(
                savedGames: self.savedGameRepository(),
                gameRecords: self.gameRecordRepository(),
            )
        }
    }

    var completeGameUseCase: Factory<any CompleteGameUseCase> {
        self {
            CompleteGame(
                gameRecords: self.gameRecordRepository(),
                savedGames: self.savedGameRepository(),
                dailyChallenges: self.dailyChallengeRepository(),
                gameCenter: self.gameCenterService(),
            )
        }
    }

    var getHintUseCase: Factory<any GetHintUseCase> {
        self { GetHint() }
    }

    var revealCellUseCase: Factory<any RevealCellUseCase> {
        self { RevealCell() }
    }
}
