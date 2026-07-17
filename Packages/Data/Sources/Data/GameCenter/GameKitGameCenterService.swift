import Common
public import Domain
import Foundation
import GameKit
public import Model

#if canImport(UIKit)
    import UIKit
#endif

/// GameKit adapter. Never blocks gameplay: authentication runs in the
/// background, failed submissions queue for retry after the next successful
/// sign-in, and every consumer sees plain `Model` values only.
public actor GameKitGameCenterService: GameCenterService {
    private var state: GameCenterAuthState = .unknown
    private var handlerInstalled = false
    private var continuations: [UUID: AsyncStream<GameCenterAuthState>.Continuation] = [:]
    private let pending = PendingSubmissionQueue()

    public init() {}

    // MARK: - Authentication

    public func authenticate() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        setState(.authenticating)

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            Task { @MainActor in
                #if canImport(UIKit)
                    if let viewController {
                        Self.presentAuthenticationUI(viewController)
                        return
                    }
                #else
                    _ = viewController // macOS test host: nothing to present.
                #endif
                if let error {
                    Log.info("Game Center authentication unavailable: \(error)")
                }
                let newState: GameCenterAuthState = GKLocalPlayer.local.isAuthenticated
                    ? .authenticated(playerName: GKLocalPlayer.local.displayName)
                    : .unauthenticated
                await self.finishAuthentication(with: newState)
            }
        }
    }

    public func currentAuthState() -> GameCenterAuthState {
        state
    }

    public nonisolated func authStateStream() -> AsyncStream<GameCenterAuthState> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(continuation, id: id) }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.unregister(id) }
            }
        }
    }

    private func register(_ continuation: AsyncStream<GameCenterAuthState>.Continuation, id: UUID) {
        continuations[id] = continuation
        continuation.yield(state)
    }

    private func unregister(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func setState(_ newState: GameCenterAuthState) {
        state = newState
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }

    private func finishAuthentication(with newState: GameCenterAuthState) async {
        setState(newState)
        if case .authenticated = newState {
            await flushPendingSubmissions()
        }
    }

    #if canImport(UIKit)
        @MainActor
        private static func presentAuthenticationUI(_ viewController: UIViewController) {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            guard let root = scene?.keyWindow?.rootViewController
                ?? scene?.windows.first?.rootViewController
            else {
                Log.info("Game Center: no window to present the sign-in UI")
                return
            }
            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(viewController, animated: true)
        }
    #endif

    // MARK: - Submissions

    public func submitScore(_ value: Int, leaderboardID: String) async {
        guard case .authenticated = state else {
            pending.enqueueScore(value, leaderboardID: leaderboardID)
            return
        }
        do {
            try await GKLeaderboard.submitScore(
                value,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID],
            )
        } catch {
            Log.error("Score submission failed (\(leaderboardID)): \(error)")
            pending.enqueueScore(value, leaderboardID: leaderboardID)
        }
    }

    public func report(_ progress: [AchievementProgress]) async {
        guard !progress.isEmpty else { return }
        guard case .authenticated = state else {
            for item in progress {
                pending.enqueueAchievement(id: item.achievement.id, percent: item.percent)
            }
            return
        }
        let achievements = progress.map { item in
            let achievement = GKAchievement(identifier: item.achievement.id)
            achievement.percentComplete = item.percent
            achievement.showsCompletionBanner = true
            return achievement
        }
        do {
            try await GKAchievement.report(achievements)
        } catch {
            Log.error("Achievement report failed: \(error)")
            for item in progress {
                pending.enqueueAchievement(id: item.achievement.id, percent: item.percent)
            }
        }
    }

    private func flushPendingSubmissions() async {
        guard !pending.isEmpty else { return }
        let queued = pending.drain()
        Log.info(
            "Game Center: retrying \(queued.scores.count) scores, "
                + "\(queued.achievements.count) achievements",
        )
        for score in queued.scores {
            await submitScore(score.value, leaderboardID: score.leaderboardID)
        }
        if !queued.achievements.isEmpty {
            let achievements = queued.achievements.map { item in
                let achievement = GKAchievement(identifier: item.achievementID)
                achievement.percentComplete = item.percent
                achievement.showsCompletionBanner = true
                return achievement
            }
            do {
                try await GKAchievement.report(achievements)
            } catch {
                Log.error("Queued achievement report failed: \(error)")
                for item in queued.achievements {
                    pending.enqueueAchievement(id: item.achievementID, percent: item.percent)
                }
            }
        }
    }

    // MARK: - Standings

    public func standings(leaderboardID: String, count: Int) async throws -> LeaderboardStandings {
        guard case .authenticated = state else {
            throw DomainError.gameCenterUnavailable
        }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
            guard let board = boards.first else { throw DomainError.notFound }

            let range = NSRange(location: 1, length: max(1, min(count, 100)))
            let (localEntry, entries, _) = try await board.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: range,
            )
            let localID = GKLocalPlayer.local.gamePlayerID
            return LeaderboardStandings(
                leaderboardID: leaderboardID,
                entries: entries.map { entry in
                    LeaderboardStandings.Entry(
                        rank: entry.rank,
                        displayName: entry.player.displayName,
                        scoreText: entry.formattedScore,
                        isLocalPlayer: entry.player.gamePlayerID == localID,
                    )
                },
                localEntry: localEntry.map { entry in
                    LeaderboardStandings.Entry(
                        rank: entry.rank,
                        displayName: entry.player.displayName,
                        scoreText: entry.formattedScore,
                        isLocalPlayer: true,
                    )
                },
            )
        } catch let error as DomainError {
            throw error
        } catch {
            Log.error("Standings load failed (\(leaderboardID)): \(error)")
            throw DomainError.gameCenterUnavailable
        }
    }

    // MARK: - Debug

    public func resetAchievements() async throws {
        guard case .authenticated = state else {
            throw DomainError.gameCenterUnavailable
        }
        do {
            try await GKAchievement.resetAchievements()
        } catch {
            throw DomainError.gameCenterUnavailable
        }
    }
}
