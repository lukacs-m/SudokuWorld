/// Compile-time feature gates. Constants (not runtime toggles) so disabled
/// branches are dead-stripped and can never leak into a release build.
public enum FeatureFlags {
    // Samurai (five overlapping 9×9 grids) is the stretch variant: fully
    // implemented, but only surfaced in development builds until it has been
    // validated at scale on real devices.
    #if DEBUG
        public static let samuraiEnabled = true
    #else
        public static let samuraiEnabled = false
    #endif
}
