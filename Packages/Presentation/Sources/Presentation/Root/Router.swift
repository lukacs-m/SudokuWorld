import Observation

/// One navigation stack's path. Every `NavigationStack` in the app binds to
/// its own router, and screens push onto whichever stack they mean to; no view
/// links to a destination on its own. The route enums live in `Routes.swift`,
/// the stack views that resolve them in `TabStacks.swift`.
@MainActor
@Observable
final class Router<Route: Hashable> {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
