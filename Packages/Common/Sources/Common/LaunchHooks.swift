import Foundation

/// DEBUG-only launch-argument hooks so development tooling (UI screenshots,
/// simulator automation) can drive the app straight to a screen without tap
/// scripting. Compiled to constants in release builds and dead-stripped.
///
/// Usage: `simctl launch <device> <bundle-id> -uiHookNewGameSheet YES`
/// or `-uiHookVariant kropki -uiHookDifficulty medium`.
public enum LaunchHooks {
    #if DEBUG
        /// Present the New Game sheet immediately on the home screen.
        public static var openNewGameSheet: Bool {
            UserDefaults.standard.bool(forKey: "uiHookNewGameSheet")
        }

        /// Start a game immediately: variant and difficulty as their slugs.
        public static var autostart: (variantSlug: String, difficultySlug: String)? {
            guard let variant = UserDefaults.standard.string(forKey: "uiHookVariant") else {
                return nil
            }
            let difficulty = UserDefaults.standard.string(forKey: "uiHookDifficulty") ?? "easy"
            return (variant, difficulty)
        }
    #else
        public static let openNewGameSheet = false
        public static let autostart: (variantSlug: String, difficultySlug: String)? = nil
    #endif
}
