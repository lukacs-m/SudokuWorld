public import Model

/// Persistence for finished games — the raw material of statistics,
/// achievements, and leaderboard submissions.
public protocol GameRecordRepository: Sendable {
    func insert(_ record: GameRecord) async throws
    /// All records, newest first.
    func allRecords() async throws -> [GameRecord]
}
