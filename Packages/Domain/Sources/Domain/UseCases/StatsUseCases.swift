public import Foundation
public import Model

/// Assembles the Statistics screen's data from records and daily completions.
public protocol ComputeStatsUseCase: Sendable {
    func callAsFunction(today: Date) async -> StatsOverview
}

public struct ComputeStats: ComputeStatsUseCase {
    private let gameRecords: any GameRecordRepository
    private let dailyChallenges: any DailyChallengeRepository
    private let aggregator = StatsAggregator()

    public init(
        gameRecords: any GameRecordRepository,
        dailyChallenges: any DailyChallengeRepository,
    ) {
        self.gameRecords = gameRecords
        self.dailyChallenges = dailyChallenges
    }

    public func callAsFunction(today: Date) async -> StatsOverview {
        let records = await (try? gameRecords.allRecords()) ?? []
        let dailyKeys = await (try? dailyChallenges.completedDateKeys()) ?? []
        return aggregator.overview(
            records: records,
            dailyCompletionKeys: dailyKeys,
            today: today,
        )
    }
}
