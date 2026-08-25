import Common
import Model
import SwiftUI

/// The statistics screen: totals, streaks, charts, and the per-variant table.
struct StatsView: View {
    @State private var viewModel = StatsViewModel()
    @State private var showPaywall = false

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
                    totals(overview: overview, theme: theme)
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

                if !viewModel.isPremium, let banner = viewModel.banner {
                    BannerAdView(creative: banner) {
                        showPaywall = true
                    }
                }
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text("stats.title", bundle: .module))
        .task { await viewModel.load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// 2×2 grid: four short captions in one row truncate on small phones.
    private func totals(overview: StatsOverview, theme _: Theme) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10,
        ) {
            StatTile("stats.played", value: "\(overview.totalPlayed)")
            StatTile("stats.winRate", value: "\(Int(overview.winRate * 100))%")
            StatTile("stats.won", value: "\(overview.totalWon)")
            StatTile("stats.lost", value: "\(overview.totalLost)")
        }
    }
}
