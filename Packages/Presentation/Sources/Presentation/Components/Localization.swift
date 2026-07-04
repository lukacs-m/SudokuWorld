import Foundation

/// Resolves a dynamically-built catalog key ("variant.\(slug)") against the
/// package bundle. Interpolating into a `LocalizedStringKey` literal would
/// turn the interpolation into a %@ placeholder and miss the catalog — this
/// takes the finished key as a plain string instead.
func moduleString(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .module)
}
