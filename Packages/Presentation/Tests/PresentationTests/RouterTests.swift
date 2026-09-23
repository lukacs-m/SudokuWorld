import Model
import Testing
@testable import Presentation

@MainActor
struct RouterTests {
    /// The Learn list used to reappear above its lesson: the list was pushed
    /// through `navigationDestination(isPresented:)` and the lesson through a
    /// typed path, and SwiftUI re-ordered the two. One typed path per stack
    /// holds exactly the screens pushed, in order.
    @Test func learnThenLessonPushesExactlyThoseTwoRoutes() {
        let router = HomeRouter()
        router.push(.learn)
        router.push(.lesson(.nakedSingle))
        #expect(router.path == [.learn, .lesson(.nakedSingle)])
    }

    @Test func popReturnsToThePreviousScreenAndPopToRootClearsTheStack() {
        let router = HomeRouter()
        router.push(.learn)
        router.push(.lesson(.xWing))
        router.pop()
        #expect(router.path == [.learn])
        router.push(.lesson(.xWing))
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test func popOnAnEmptyStackIsANoOp() {
        let router = SettingsRouter()
        router.pop()
        #expect(router.path.isEmpty)
    }
}

@MainActor
struct AppRouterTests {
    @Test func playingTheSameLaunchTwicePresentsAFreshCoverEachTime() {
        let router = AppRouter()
        let launch = GameLaunch(kind: .new(variant: .classic, difficulty: .easy, mode: .normal))
        router.play(launch)
        let first = router.presentedFullScreen
        router.play(launch)
        #expect(first != nil)
        #expect(router.presentedFullScreen != first)
        if case let .game(presentation)? = router.presentedFullScreen {
            #expect(presentation.launch == launch)
        } else {
            Issue.record("expected a game cover")
        }
    }

    @Test func goHomeDismissesTheGameAndSelectsTheHomeTab() {
        let router = AppRouter()
        router.selectedTab = .stats
        router.play(GameLaunch(kind: .resume))
        router.goHome()
        #expect(router.presentedFullScreen == nil)
        #expect(router.selectedTab == .home)
    }

    @Test func dismissGameKeepsTheSelectedTab() {
        let router = AppRouter()
        router.selectedTab = .events
        router.play(GameLaunch(kind: .resume))
        router.dismissGame()
        #expect(router.presentedFullScreen == nil)
        #expect(router.selectedTab == .events)
    }
}
