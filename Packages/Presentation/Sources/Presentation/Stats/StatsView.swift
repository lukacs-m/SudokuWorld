import Common
import Model
import SwiftUI

/// The statistics screen: totals, streaks, charts, and the per-variant table.
struct StatsView: View {
    @State private var viewModel = StatsViewModel()

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        ScrollView {
            VStack(spacing: 16) {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)

                case .empty:
                    ContentUnavailableView {
                        Label {
                            Text("stats.empty.title", bundle: .module)
                        } icon: {
                            Image(systemName: "chart.bar")
                        }
                    } description: {
                        Text("stats.empty.message", bundle: .module)
                    }

                case let .loaded(overview):
                    StatsTotalsGrid(overview: overview)
                    StreakBadgeView(streaks: overview.streaks)
                    StatsChartsView(overview: overview)
                    VariantBreakdownView(overview: overview)

                case .failed:
                    ContentUnavailableView {
                        Label {
                            Text("stats.failed", bundle: .module)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text("stats.title", bundle: .module))
        .task { await viewModel.load() }
    }
}
