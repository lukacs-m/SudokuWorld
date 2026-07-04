import Domain
import Foundation
import Model

// MARK: - Fixtures

nonisolated enum TestFixtures {
    /// The Wikipedia example puzzle — instant, no generation needed.
    static let classicGivens: [Int?] = parse(
        "530070000600195000098000060800060003400803001700020006060000280000419005000080079",
    ).map { $0 == 0 ? nil : $0 }

    static let classicSolution: [Int] = parse(
        "534678912672195348198342567859761423426853791713924856961537284287419635345286179",
    )

    private static func parse(_ text: String) -> [Int] {
        text.compactMap { Int(String($0)) }
    }

    static func puzzle(
        givens: [Int?]? = nil,
        variant: SudokuVariant = .classic,
        difficulty: Difficulty = .easy,
    ) -> PuzzleDefinition {
        PuzzleDefinition(
            id: UUID(),
            variant: variant,
            requestedDifficulty: difficulty,
            gradedDifficulty: difficulty,
            seed: 7,
            givens: givens ?? classicGivens,
            solution: classicSolution,
        )
    }

    /// A puzzle with exactly one empty cell — one correct move from solved.
    static func almostSolvedPuzzle() -> PuzzleDefinition {
        var givens: [Int?] = classicSolution
        givens[0] = nil
        return puzzle(givens: givens)
    }

    static func session(
        puzzle: PuzzleDefinition = puzzle(),
        mode: GameMode = .normal,
        context: GameContext = .regular,
    ) -> GameSession {
        GameSession(
            puzzle: puzzle,
            mode: mode,
            context: context,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
        )
    }

    static func summary(outcome: GameOutcome) -> CompletionSummary {
        CompletionSummary(
            outcome: outcome,
            duration: 200,
            mistakes: 0,
            hintsUsed: 0,
            isPersonalBest: false,
            earnedAchievements: [],
            dailyStreak: 0,
            tournamentPoints: 0,
        )
    }
}

// MARK: - Game lifecycle mocks

nonisolated struct MockStartGame: StartGameUseCase {
    var puzzle: PuzzleDefinition = TestFixtures.puzzle()

    func callAsFunction(
        variant: SudokuVariant,
        difficulty: Difficulty,
        mode: GameMode,
        context: GameContext,
        at now: Date,
    ) async -> GameSession {
        GameSession(puzzle: puzzle, mode: mode, context: context, startedAt: now)
    }
}

nonisolated struct MockResumeGame: ResumeGameUseCase {
    var saved: SavedGame?

    func callAsFunction(context: GameContext) async -> GameSession? {
        saved.map(GameSession.init(restoring:))
    }
}

/// Records autosave snapshots for assertions.
actor SaveRecorder {
    private(set) var snapshots: [SavedGame] = []

    func record(_ snapshot: SavedGame) {
        snapshots.append(snapshot)
    }
}

nonisolated struct MockSaveGame: SaveGameUseCase {
    let recorder: SaveRecorder

    func callAsFunction(_ snapshot: SavedGame) async {
        await recorder.record(snapshot)
    }
}

nonisolated struct MockAbandonGame: AbandonGameUseCase {
    func callAsFunction(session: GameSession, at now: Date) async {}
}

/// Records completions and returns a canned summary.
actor CompletionRecorder {
    private(set) var outcomes: [GameOutcome] = []

    func record(_ outcome: GameOutcome) {
        outcomes.append(outcome)
    }
}

nonisolated struct MockCompleteGame: CompleteGameUseCase {
    let recorder: CompletionRecorder

    func callAsFunction(
        session: GameSession,
        outcome: GameOutcome,
        at now: Date,
    ) async -> CompletionSummary {
        await recorder.record(outcome)
        return TestFixtures.summary(outcome: outcome)
    }
}

// MARK: - Hint mocks

nonisolated struct MockGetHint: GetHintUseCase {
    func callAsFunction(board: Board, puzzle: PuzzleDefinition) async -> Hint? {
        guard let index = (0..<board.count).first(where: { board[$0].value == nil }) else {
            return nil
        }
        return Hint(
            kind: .logical(.nakedSingle),
            cells: [index],
            placement: Hint.Placement(index: index, digit: puzzle.solution[index]),
            explanationKey: "hint.technique.nakedSingle",
        )
    }
}

nonisolated struct MockRevealCell: RevealCellUseCase {
    func callAsFunction(
        board: Board,
        puzzle: PuzzleDefinition,
        preferredCell: Int?,
    ) async -> Hint? {
        HintEngine().revealHint(preferredCell: preferredCell, board: board, puzzle: puzzle)
    }
}

// MARK: - Monetization mocks

nonisolated struct MockGetEntitlements: GetEntitlementsUseCase {
    var entitlements: Entitlements = .free

    func callAsFunction() async -> Entitlements {
        entitlements
    }
}

nonisolated struct MockInterstitialGate: InterstitialGateUseCase {
    var creative: AdCreative?

    func callAsFunction(at now: Date) async -> AdCreative? {
        creative
    }
}

nonisolated struct MockGetBanner: GetBannerUseCase {
    var creative: AdCreative?

    func callAsFunction(placement: AdPlacement) async -> AdCreative? {
        creative
    }
}

nonisolated struct MockGetOfferings: GetOfferingsUseCase {
    var result: Result<PaywallOfferings, DomainError> = .success(.empty)

    func callAsFunction() async throws -> PaywallOfferings {
        try result.get()
    }
}

nonisolated struct MockPurchasePremium: PurchasePremiumUseCase {
    var result: Result<Entitlements, DomainError> =
        .success(Entitlements(isPremium: true, source: .subscription))

    func callAsFunction(productID: String) async throws -> Entitlements {
        try result.get()
    }
}

nonisolated struct MockRestorePurchases: RestorePurchasesUseCase {
    var result: Result<Entitlements, DomainError> = .success(.free)

    func callAsFunction() async throws -> Entitlements {
        try result.get()
    }
}

// MARK: - Stats & events mocks

nonisolated struct MockComputeStats: ComputeStatsUseCase {
    var overview: StatsOverview = .empty

    func callAsFunction(today: Date) async -> StatsOverview {
        overview
    }
}

nonisolated struct MockGetDailyChallenge: GetDailyChallengeUseCase {
    var completed = false

    func callAsFunction(now: Date) async -> DailyChallenge {
        DailyChallenge(
            dateKey: EventSeeds.dailyDateKey(for: now),
            endsAt: EventSeeds.nextDailyReset(after: now),
            puzzle: TestFixtures.puzzle(),
            isCompleted: completed,
            completionTime: completed ? 300 : nil,
        )
    }
}

nonisolated struct MockGetWeeklyTournament: GetWeeklyTournamentUseCase {
    func callAsFunction(now: Date) async -> WeeklyTournament {
        WeeklyTournament(
            weekKey: EventSeeds.weekKey(for: now),
            variant: .killer,
            difficulty: .medium,
            endsAt: EventSeeds.weekEnd(for: now),
            points: 1500,
            gamesCounted: 2,
        )
    }
}

nonisolated struct MockGetStandings: GetStandingsUseCase {
    var result: Result<LeaderboardStandings, DomainError> = .failure(.gameCenterUnavailable)

    func callAsFunction(leaderboardID: String, count: Int) async throws -> LeaderboardStandings {
        try result.get()
    }
}

nonisolated struct MockObserveGameCenterAuth: ObserveGameCenterAuthUseCase {
    var state: GameCenterAuthState = .unauthenticated

    func callAsFunction() -> AsyncStream<GameCenterAuthState> {
        let captured = state
        return AsyncStream { continuation in
            continuation.yield(captured)
            continuation.finish()
        }
    }
}

nonisolated struct MockAuthenticateGameCenter: AuthenticateGameCenterUseCase {
    func callAsFunction() async {}
}

nonisolated struct MockUpdateReminders: UpdateRemindersUseCase {
    var authorized = true

    func callAsFunction(
        preferences: NotificationPreferences,
        copy: ReminderCopy,
        now: Date,
    ) async -> Bool {
        authorized
    }
}

// MARK: - Settings repository mock

actor MockSettingsRepository: SettingsRepository {
    private var settings: GameSettings
    private var notifications: NotificationPreferences

    init(
        settings: GameSettings = .standard,
        notifications: NotificationPreferences = .disabled,
    ) {
        self.settings = settings
        self.notifications = notifications
    }

    func gameSettings() async -> GameSettings {
        settings
    }

    func setGameSettings(_ settings: GameSettings) async {
        self.settings = settings
    }

    func notificationPreferences() async -> NotificationPreferences {
        notifications
    }

    func setNotificationPreferences(_ preferences: NotificationPreferences) async {
        notifications = preferences
    }
}
