import Common
import Domain
import Foundation
import Model
import SwiftUI

/// The events hub: daily challenge and weekly tournament cards with
/// countdowns, plus live standings from Game Center.
struct EventsHubView: View {
    @State private var viewModel = EventsHubViewModel()

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
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text("events.title", bundle: .module))
        .task { await viewModel.load() }
        .task { await viewModel.observeAuthState() }
        .onChange(of: router.game) { _, game in
            // The game cover doesn't refire onAppear underneath on dismissal.
            if game == nil {
                Task { await viewModel.load() }
            }
        }
    }

    private func dailyCard(_ daily: DailyLineup, theme: Theme) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
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

                Text("events.daily.subtitle", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)

                weekStrip(theme: theme)

                HStack(spacing: 6) {
                    Text("events.daily.today", bundle: .module)
                    Text("·")
                    Text(Date.now.formatted(.dateTime.month(.wide).day()))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

                ForEach(daily.slots, id: \.variant) { slot in
                    DailySlotRow(slot: slot, theme: theme) {
                        router.play(GameLaunch(kind: .daily(
                            dateKey: daily.dateKey,
                            variant: slot.variant,
                            difficulty: slot.difficulty,
                        )))
                    }
                    if slot != daily.slots.last {
                        Divider()
                    }
                }

                HStack(spacing: 10) {
                    StatTile(
                        "events.daily.streakTile",
                        value: "\(viewModel.streaks.currentDailyStreak)",
                    )
                    StatTile(
                        "events.daily.completedTile",
                        value: "\(Int(viewModel.completionRate * 100))%",
                    )
                }

                archiveLink(theme: theme)

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

    private func archiveLink(theme: Theme) -> some View {
        NavigationLink {
            DailyArchiveView()
        } label: {
            HStack {
                Label {
                    Text("events.archive", bundle: .module)
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(theme.accent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
    }

    /// The mock's week strip: this week's days, today accented, completed
    /// days tinted. Completion keys are UTC (the daily clock authority).
    private func weekStrip(theme: Theme) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let delta = (calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -delta, to: today) ?? today
        let days = (0 ..< 7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let isCompleted = viewModel.completedDayKeys
                    .contains(EventSeeds.dailyDateKey(for: day))
                let isFuture = day > today
                VStack(spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                    Text("\(calendar.component(.day, from: day))")
                        .font(.subheadline.weight(isToday ? .bold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(
                            isToday ? Color.white
                                : isCompleted ? theme.accent : theme.textPrimary,
                        )
                        .frame(width: 32, height: 32)
                        .background(
                            isToday ? theme.accent
                                : isCompleted ? theme.accent.opacity(0.15) : .clear,
                            in: Circle(),
                        )
                }
                .frame(maxWidth: .infinity)
                .opacity(isFuture ? 0.35 : 1)
            }
        }
        .accessibilityHidden(true)
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
                    router.play(GameLaunch(kind: .weekly(
                        variant: weekly.variant,
                        difficulty: weekly.difficulty,
                    )))
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
