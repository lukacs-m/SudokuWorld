import Model

/// The screens each navigation stack can push, one enum per stack. A stack's
/// view resolves its enum in a single `navigationDestination(for:)` switch.

enum HomeRoute: Hashable {
    case learn
    case lesson(Technique)
}

enum EventsRoute: Hashable {
    case dailyArchive
}

enum StatsRoute: Hashable {
    case mastery(StatsOverview)
    case variantDetail(SudokuVariant, StatsOverview)
}

enum SettingsRoute: Hashable {
    case learn
    case lesson(Technique)
    #if DEBUG
        case debug
    #endif
}

enum NewGameRoute: Hashable {
    case difficulty
}

/// Modal stacks that exist for their navigation bar alone: nothing can be
/// pushed onto them until a case is added here.
enum GameRoute: Hashable {}
enum RulesRoute: Hashable {}
enum PaywallRoute: Hashable {}
enum LessonSheetRoute: Hashable {}

typealias HomeRouter = Router<HomeRoute>
typealias EventsRouter = Router<EventsRoute>
typealias StatsRouter = Router<StatsRoute>
typealias SettingsRouter = Router<SettingsRoute>
typealias NewGameRouter = Router<NewGameRoute>
typealias GameRouter = Router<GameRoute>
typealias RulesRouter = Router<RulesRoute>
typealias PaywallRouter = Router<PaywallRoute>
typealias LessonSheetRouter = Router<LessonSheetRoute>
