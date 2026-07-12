public import SwiftUI

/// The filled accent button used for primary actions. All chrome lives
/// inside the label with an explicit content shape, so the entire filled
/// area is tappable (with `.plain`, only the label's content shape hits).
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
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
