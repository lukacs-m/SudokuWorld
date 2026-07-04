/// Third-party API keys. These are the ONLY placeholders in the codebase:
/// the app runs fully without them (purchases disabled → permanent free
/// tier, simulated ads). Paste real keys here before shipping — see the
/// README's "RevenueCat setup" section.
enum AppSecrets {
    /// RevenueCat public SDK key (starts with "appl_" for App Store apps).
    static let revenueCatAPIKey = "REPLACE_ME_REVENUECAT_API_KEY"

    static var revenueCatKeyIsPlaceholder: Bool {
        revenueCatAPIKey.hasPrefix("REPLACE_ME")
    }
}
