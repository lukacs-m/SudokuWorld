/// A renderable ad, provider-agnostic. The simulated provider ships house
/// creatives; a real network adapter maps its payloads into this same shape.
public struct AdCreative: Identifiable, Equatable, Sendable {
    public enum Format: Equatable, Sendable {
        case banner
        case interstitial
    }

    public let id: String
    public let format: Format
    public let headline: String
    public let body: String
    public let callToAction: String
    /// Interstitials cannot be dismissed before this many seconds.
    public let minimumDisplaySeconds: Int

    public init(
        id: String,
        format: Format,
        headline: String,
        body: String,
        callToAction: String,
        minimumDisplaySeconds: Int = 0,
    ) {
        self.id = id
        self.format = format
        self.headline = headline
        self.body = body
        self.callToAction = callToAction
        self.minimumDisplaySeconds = minimumDisplaySeconds
    }
}

/// Where an ad may appear. Interstitials are only ever requested between
/// games — never mid-puzzle.
public enum AdPlacement: String, Equatable, Sendable {
    case homeBanner
    case statsBanner
    case eventsBanner
    case betweenGames
}
