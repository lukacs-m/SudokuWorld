/// Compile-time feature gates. Constants (not runtime toggles) so disabled
/// branches are dead-stripped and can never leak into a release build.
/// Currently empty: samurai shipped and lost its gate.
public enum FeatureFlags {}
