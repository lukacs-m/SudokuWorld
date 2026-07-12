/// Domain-level error vocabulary. Adapters map low-level failures (StoreKit,
/// GameKit, SwiftData, URL loading) into these before they cross a boundary.
public enum DomainError: Error, Equatable, Sendable {
    /// Purchases are not configured (placeholder API key) or unreachable.
    case purchasesUnavailable
    /// The player cancelled a purchase mid-flow.
    case purchaseCancelled
    /// Game Center is unavailable or the player is not authenticated.
    case gameCenterUnavailable
    /// A persistence read/write failed.
    case persistence
    case notFound
    case network
    case unknown
}
