import SwiftUI

/// The small "the fog lifts" pill shown in its own slot under the board —
/// never covering cells — when fair fog's never-stuck rule reveals a window
/// on its own.
struct FogLiftCueView: View {
    let theme: Theme

    var body: some View {
        Label {
            Text("game.fogLifts", bundle: .module)
        } icon: {
            Image(systemName: "cloud.fog")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.cardBackground, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.gridLine))
        .accessibilityElement(children: .combine)
    }
}
