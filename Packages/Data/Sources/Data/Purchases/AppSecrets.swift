/// Third-party API keys. The app runs fully without a real key (purchases
/// disabled → permanent free tier) — see the README's "RevenueCat setup"
/// section.
enum AppSecrets {
    /// RevenueCat public SDK key. Currently the sandbox test-store key
    /// ("test_…"); swap in the production "appl_…" key before shipping.
    static let revenueCatAPIKey = "test_txBSGiwuLLgGAFJwYiOQuCjnEZA"

    static var revenueCatKeyIsPlaceholder: Bool {
        revenueCatAPIKey.hasPrefix("REPLACE_ME")
    }
}
