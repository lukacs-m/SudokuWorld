import SwiftUI

/// A list row that pushes a screen: the label plus the disclosure chevron a
/// system-linked row would draw. The action pushes onto the stack's router.
struct DisclosureRow<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack {
                label
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .foregroundStyle(.primary)
    }
}
