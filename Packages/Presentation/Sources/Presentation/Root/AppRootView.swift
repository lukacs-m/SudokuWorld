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

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .environment(router)
        .environment(themeStore)
        .tint(themeStore.theme(for: .light).accent)
        .task {
            guard !launched else { return }
            launched = true
            await themeStore.load()
            await LaunchTasks.run()
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case let .game(launch):
            GameView(launch: launch)
        case .stats:
            StatsView()
        case .events:
            EventsHubView()
        case .settings:
            SettingsView()
        case .debug:
            #if DEBUG
                DebugMenuView()
            #else
                EmptyView()
            #endif
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
