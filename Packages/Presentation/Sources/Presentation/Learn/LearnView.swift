import Model
import SwiftUI

/// The learning section's technique list, grouped by difficulty band. Each
/// row hands the technique to the owning stack, which pushes its lesson.
struct LearnView: View {
    let onSelect: (Technique) -> Void

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        List {
            ForEach(LessonGroup.allCases, id: \.self) { group in
                Section {
                    ForEach(group.techniques, id: \.self) { technique in
                        DisclosureRow {
                            onSelect(technique)
                        } label: {
                            Text(verbatim: technique.lessonName)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                } header: {
                    Text(group.titleKey, bundle: .module)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.screenBackground)
        .navigationTitle(Text("learn.title", bundle: .module))
    }
}
