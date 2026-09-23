import Model
import SwiftUI

/// One view per `NavigationStack`: binds the stack to its router and holds
/// the stack's only `navigationDestination(for:)` switch. Declaring the
/// switch anywhere but the stack root (or presenting a screen through
/// `navigationDestination(isPresented:)`) lets SwiftUI re-order the pushed
/// screens, which is how the Learn list used to reappear above its lesson.

struct HomeStack: View {
    @Environment(HomeRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .learn:
                        LearnView { router.push(.lesson($0)) }
                    case let .lesson(technique):
                        LessonView(technique: technique)
                    }
                }
        }
    }
}

struct EventsStack: View {
    @Environment(EventsRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            EventsHubView()
                .navigationDestination(for: EventsRoute.self) { route in
                    switch route {
                    case .dailyArchive:
                        DailyArchiveView()
                    }
                }
        }
    }
}

struct StatsStack: View {
    @Environment(StatsRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            StatsView()
                .navigationDestination(for: StatsRoute.self) { route in
                    switch route {
                    case let .mastery(overview):
                        MasteryMatrixView(overview: overview)
                    case let .variantDetail(variant, overview):
                        VariantDetailView(variant: variant, overview: overview)
                    }
                }
        }
    }
}

struct SettingsStack: View {
    @Environment(SettingsRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            SettingsView()
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .learn:
                        LearnView { router.push(.lesson($0)) }
                    case let .lesson(technique):
                        LessonView(technique: technique)
                    #if DEBUG
                        case .debug:
                            DebugMenuView()
                    #endif
                    }
                }
        }
    }
}

/// The game cover's stack, owned for the cover's lifetime.
struct GameStack: View {
    let launch: GameLaunch

    @State private var router = GameRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            GameView(launch: launch)
        }
    }
}
