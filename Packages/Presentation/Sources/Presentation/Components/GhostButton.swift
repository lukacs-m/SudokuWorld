public import SwiftUI

/// The bordered-neutral secondary button paired with `PrimaryButton`.
public struct GhostButton: View {
    private let titleKey: LocalizedStringKey
    private let systemImage: String?
    private let action: () -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        action: @escaping () -> Void,
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(titleKey, bundle: .module)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.gridLine),
            )
            .foregroundStyle(theme.textPrimary)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
