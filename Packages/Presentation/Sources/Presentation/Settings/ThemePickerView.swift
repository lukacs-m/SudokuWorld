import Model
import SwiftUI

/// Theme swatches with premium locks. Selecting a locked theme raises the
/// paywall via `onLocked`.
struct ThemePickerView: View {
    let selected: ThemeID
    let isPremium: Bool
    let onSelect: (ThemeID) -> Void
    let onLocked: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
            ForEach(ThemeID.allCases, id: \.self) { id in
                swatch(id)
            }
        }
    }

    private func swatch(_ id: ThemeID) -> some View {
        let palette = ThemePalettes.palette(for: id, scheme: colorScheme)
        let locked = id.isPremium && !isPremium
        let isSelected = id == selected

        return Button {
            if locked {
                onLocked()
            } else {
                onSelect(id)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(palette.screenBackground)
                    HStack(spacing: 3) {
                        Circle().fill(palette.accent).frame(width: 14, height: 14)
                        Circle().fill(palette.cellBackgroundAlternate).frame(width: 14, height: 14)
                        Circle().fill(palette.givenText).frame(width: 14, height: 14)
                    }
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.5), in: Circle())
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .topTrailing,
                            )
                            .padding(4)
                    }
                }
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? palette.accent : .clear,
                            lineWidth: 2,
                        ),
                )
                Text(verbatim: moduleString("theme.\(id.rawValue)"))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: moduleString("theme.\(id.rawValue)")))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
