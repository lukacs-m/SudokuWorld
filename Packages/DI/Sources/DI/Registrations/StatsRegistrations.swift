public import Domain
public import FactoryKit

/// Statistics wiring.
public extension Container {
    var computeStatsUseCase: Factory<any ComputeStatsUseCase> {
        self {
            ComputeStats(
                gameRecords: self.gameRecordRepository(),
                dailyChallenges: self.dailyChallengeRepository(),
            )
        }
    }
}
