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

        /// Select a root tab at launch: `-uiHookTab <home|events|stats|settings>`.
        public static var initialTab: String? {
            UserDefaults.standard.string(forKey: "uiHookTab")
        }

        /// Seed fake game records and daily completions so data-driven
        /// screens (stats, week strip) can be screenshotted: `-uiHookSeedStats YES`.
        public static var seedStats: Bool {
            UserDefaults.standard.bool(forKey: "uiHookSeedStats")
        }

        /// Open the rules sheet for a variant inside the New Game sheet:
        /// `-uiHookNewGameSheet YES -uiHookRules <variant-slug>`.
        public static var rulesVariant: String? {
            UserDefaults.standard.string(forKey: "uiHookRules")
        }

        /// Present the paywall immediately on the home screen:
        /// `-uiHookPaywall YES`.
        public static var openPaywall: Bool {
            UserDefaults.standard.bool(forKey: "uiHookPaywall")
        }

        /// Select a board cell once the game has started: `-uiHookSelectCell 4`.
        public static var selectCell: Int? {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: "uiHookSelectCell") != nil else { return nil }
            return defaults.integer(forKey: "uiHookSelectCell")
        }

        /// Start the cube board turned by yaw then pitch, in degrees:
        /// `-uiHookCubeYaw 35 -uiHookCubePitch 25` — a leading `-` on the
        /// value is parsed as another key, so keep both positive.
        public static var cubePose: (yaw: Double, pitch: Double)? {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: "uiHookCubeYaw") != nil
                || defaults.object(forKey: "uiHookCubePitch") != nil
            else { return nil }
            return (
                defaults.double(forKey: "uiHookCubeYaw"),
                defaults.double(forKey: "uiHookCubePitch"),
            )
        }

        /// Push the learning section from the home screen: `-uiHookLearn YES`.
        public static var openLearn: Bool {
            UserDefaults.standard.bool(forKey: "uiHookLearn")
        }

        /// Push one lesson from the home screen: `-uiHookLesson <technique>`
        /// (a `Technique` raw value, e.g. `xWing`).
        public static var lessonTechnique: String? {
            UserDefaults.standard.string(forKey: "uiHookLesson")
        }
    #else
        public static let openNewGameSheet = false
        public static let autostart: (variantSlug: String, difficultySlug: String)? = nil
        public static let initialTab: String? = nil
        public static let seedStats = false
        public static let rulesVariant: String? = nil
        public static let openPaywall = false
        public static let selectCell: Int? = nil
        public static let cubePose: (yaw: Double, pitch: Double)? = nil
        public static let openLearn = false
        public static let lessonTechnique: String? = nil
    #endif
}
