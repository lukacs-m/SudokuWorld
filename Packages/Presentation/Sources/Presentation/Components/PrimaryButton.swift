public import SwiftUI

/// The filled accent button used for primary actions.
public struct PrimaryButton: View {
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
                }
                Text(titleKey, bundle: .module)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.white)
    }
}
