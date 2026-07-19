import Common
import DI
import Domain
import Foundation
import Model
public import SwiftUI

/// The app's root: owns the navigation stack, the theme store, and the
/// launch-time side effects (purchases configuration, Game Center sign-in,
/// reminder rescheduling). The app target's `@main` hands off here.
public struct AppRootView: View {
    @State private var router = Router()
    @State private var themeStore = ThemeStore()
    @State private var launched = false
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(value: AppTab.home) {
                NavigationStack { HomeView() }
            } label: {
                Label {
                    Text("tab.home", bundle: .module)
                } icon: {
                    Image(systemName: "house")
                }
            }
            Tab(value: AppTab.events) {
                NavigationStack { EventsHubView() }
            } label: {
                Label {
                    Text("home.events", bundle: .module)
                } icon: {
                    Image(systemName: "trophy")
                }
            }
            Tab(value: AppTab.stats) {
                NavigationStack { StatsView() }
            } label: {
                Label {
                    Text("home.stats", bundle: .module)
                } icon: {
                    Image(systemName: "chart.bar")
                }
            }
            Tab(value: AppTab.settings) {
                NavigationStack { SettingsView() }
            } label: {
                Label {
                    Text("home.settings", bundle: .module)
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(item: $router.game) { presentation in
            NavigationStack { GameView(launch: presentation.launch) }
        }
        #else
                // fullScreenCover doesn't exist on macOS (test builds only).
        .sheet(item: $router.game) { presentation in
                    NavigationStack { GameView(launch: presentation.launch) }
                }
        #endif
                .environment(router)
                .environment(themeStore)
                .tint(themeStore.theme(for: colorScheme).accent)
                .preferredColorScheme(themeStore.preferredColorScheme)
                .task {
                    guard !launched else { return }
                    launched = true
                    #if DEBUG
                        switch LaunchHooks.initialTab {
                        case "events": router.selectedTab = .events
                        case "stats": router.selectedTab = .stats
                        case "settings": router.selectedTab = .settings
                        default: break
                        }
                        if LaunchHooks.seedStats {
                            await DebugSeeder.seed()
                        }
                    #endif
                    await themeStore.load()
                    await LaunchTasks.run()
                }
    }
}

/// Launch-time side effects, off the view for clarity and testability.
/// (Dependencies are bound to locals before their `callAsFunction` — chaining
/// resolution and call in one expression crashes the Swift 6.3 SILGen.)
@MainActor
enum LaunchTasks {
    static func run() async {
        let container = Container.shared

        let configurePurchases = container.configurePurchasesUseCase()
        await configurePurchases()

        let authenticate = container.authenticateGameCenterUseCase()
        await authenticate()

        // Re-arm local reminders according to current preferences.
        let settingsRepository = container.settingsRepository()
        let preferences = await settingsRepository.notificationPreferences()
        guard preferences.dailyReminderEnabled || preferences.streakReminderEnabled else {
            return
        }
        let updateReminders = container.updateRemindersUseCase()
        let copy = ReminderCopy.fromCatalog()
        _ = await updateReminders(preferences: preferences, copy: copy, now: Date())
    }
}

extension ReminderCopy {
    /// Localized reminder texts, built here so every user-facing string lives
    /// in Presentation's string catalog.
    static func fromCatalog() -> ReminderCopy {
        ReminderCopy(
            dailyTitle: String(localized: "notification.daily.title", bundle: .module),
            dailyBody: String(localized: "notification.daily.body", bundle: .module),
            streakTitle: String(localized: "notification.streak.title", bundle: .module),
            streakBody: String(localized: "notification.streak.body", bundle: .module),
        )
    }
}
