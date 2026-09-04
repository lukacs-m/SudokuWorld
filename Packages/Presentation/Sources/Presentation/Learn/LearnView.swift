import Model
import SwiftUI

/// The learning section's technique list, grouped by difficulty band. Each
/// row pushes the technique's lesson.
struct LearnView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        List {
            ForEach(LessonGroup.allCases, id: \.self) { group in
                Section {
                    ForEach(group.techniques, id: \.self) { technique in
                        NavigationLink(value: technique) {
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
        .navigationDestination(for: Technique.self) { technique in
            LessonView(technique: technique)
        }
    }
}
