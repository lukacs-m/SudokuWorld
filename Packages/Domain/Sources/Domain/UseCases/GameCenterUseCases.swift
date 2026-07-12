public import Model

/// Kicks off Game Center authentication (never blocks gameplay).
public protocol AuthenticateGameCenterUseCase: Sendable {
    func callAsFunction() async
}

public struct AuthenticateGameCenter: AuthenticateGameCenterUseCase {
    private let gameCenter: any GameCenterService

    public init(gameCenter: any GameCenterService) {
        self.gameCenter = gameCenter
    }

    public func callAsFunction() async {
        await gameCenter.authenticate()
    }
}

/// Streams authentication state for badges and the events hub.
public protocol ObserveGameCenterAuthUseCase: Sendable {
    func callAsFunction() -> AsyncStream<GameCenterAuthState>
}

public struct ObserveGameCenterAuth: ObserveGameCenterAuthUseCase {
    private let gameCenter: any GameCenterService

    public init(gameCenter: any GameCenterService) {
        self.gameCenter = gameCenter
    }

    public func callAsFunction() -> AsyncStream<GameCenterAuthState> {
        gameCenter.authStateStream()
    }
}

/// Debug-menu achievement reset.
public protocol ResetAchievementsUseCase: Sendable {
    func callAsFunction() async throws
}

public struct ResetAchievements: ResetAchievementsUseCase {
    private let gameCenter: any GameCenterService

    public init(gameCenter: any GameCenterService) {
        self.gameCenter = gameCenter
    }

    public func callAsFunction() async throws {
        try await gameCenter.resetAchievements()
    }
}
