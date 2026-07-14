import Common
import Domain
import Foundation
import Model
import SwiftUI

/// The events hub: daily challenge and weekly tournament cards with
/// countdowns, plus live standings from Game Center.
struct EventsHubView: View {
    @State private var viewModel = EventsHubViewModel()
    @State private var showPaywall = false

    @Environment(Router.self) private var router
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

                case let .loaded(content):
                    dailyCard(content.daily, theme: theme)
                    weeklyCard(content.weekly, theme: theme)

                case .empty, .failed:
                    ContentUnavailableView {
                        Label {
                            Text("events.failed", bundle: .module)
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
        .navigationTitle(Text("events.title", bundle: .module))
        .task { await viewModel.load() }
        .task { await viewModel.observeAuthState() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func dailyCard(_ daily: DailyChallenge, theme: Theme) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text("events.daily.title", bundle: .module)
                            .font(.headline)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(theme.accent)
                    }
                    Spacer()
                    CountdownText(until: daily.endsAt)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                }

                HStack(spacing: 6) {
                    Text(verbatim: moduleString("variant.\(daily.puzzle.variant.slug)"))
                    Text("·")
                    Text(verbatim: moduleString(
                        "difficulty.\(daily.puzzle.requestedDifficulty.slug)",
                    ))
                }
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

                dailyStatus(daily, theme: theme)

                Divider()
                Text("events.standings.daily", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                StandingsListView(
                    standings: viewModel.dailyStandings,
                    authState: viewModel.authState,
                )
            }
        }
    }

    /// Completed badge (with time when known) or the play button.
    @ViewBuilder
    private func dailyStatus(_ daily: DailyChallenge, theme: Theme) -> some View {
        if daily.isCompleted {
            Label {
                if let time = daily.completionTime {
                    Text(
                        String(
                            format: String(localized: "events.daily.done", bundle: .module),
                            DurationFormatter.string(for: time),
                        ),
                    )
                } else {
                    Text("events.daily.doneNoTime", bundle: .module)
                }
            } icon: {
                Image(systemName: "checkmark.seal.fill")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme.success)
        } else {
            PrimaryButton("events.daily.play", systemImage: "play.fill") {
                router.push(.game(GameLaunch(kind: .daily)))
            }
        }
    }

    private func weeklyCard(_ weekly: WeeklyTournament, theme: Theme) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text("events.weekly.title", bundle: .module)
                            .font(.headline)
                    } icon: {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(theme.accent)
                    }
                    Spacer()
                    CountdownText(until: weekly.endsAt)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                }

                HStack(spacing: 6) {
                    Text(verbatim: moduleString("variant.\(weekly.variant.slug)"))
                    Text("·")
                    Text(verbatim: moduleString("difficulty.\(weekly.difficulty.slug)"))
                }
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

                HStack(spacing: 10) {
                    StatTile("events.weekly.points", value: "\(weekly.points)")
                    StatTile("events.weekly.games", value: "\(weekly.gamesCounted)")
                }

                PrimaryButton("events.weekly.play", systemImage: "play.fill") {
                    router.push(.game(GameLaunch(kind: .weekly(
                        variant: weekly.variant,
                        difficulty: weekly.difficulty,
                    ))))
                }

                Divider()
                Text("events.standings.weekly", bundle: .module)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                StandingsListView(
                    standings: viewModel.weeklyStandings,
                    authState: viewModel.authState,
                )
            }
        }
    }
}
