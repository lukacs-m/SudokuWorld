import Common
import DI
import Domain
import Foundation
import Model
import SwiftUI

/// Past dailies, newest first, back to the rotation epoch. Rows fetch their
/// lineup lazily; a board only generates when a day is actually launched.
/// Premium replays any day; free players get the soft wall.
@MainActor
@Observable
final class DailyArchiveViewModel {
    /// Yesterday back to the 2026-01-01 rotation epoch, newest first.
    let dateKeys: [String]
    private(set) var lineups: [String: DailyLineup] = [:]
    /// Bumped after a game ends so visible rows re-fetch completion state.
    private(set) var generation = 0

    @ObservationIgnored @Injected(\.getDailyLineupUseCase) private var getDailyLineup
    @ObservationIgnored @Injected(\.resumeGameUseCase) private var resumeGame

    init(now: Date = Date()) {
        let calendar = EventSeeds.utcCalendar
        var keys: [String] = []
        if let epoch = EventSeeds.date(fromDateKey: "2026-01-01") {
            var day = calendar.startOfDay(for: now)
            while let previous = calendar.date(byAdding: .day, value: -1, to: day),
                  previous >= epoch
            {
                day = previous
                keys.append(EventSeeds.dailyDateKey(for: day))
            }
        }
        dateKeys = keys
    }

    func load(dateKey: String) async {
        lineups[dateKey] = await getDailyLineup(dateKey: dateKey)
    }

    /// A daily started on its day stays playable to completion for free
    /// players — a saved game bypasses the soft wall.
    func hasSavedGame(dateKey: String, variant: SudokuVariant) async -> Bool {
        await resumeGame(context: .daily(dateKey: dateKey, variant: variant)) != nil
    }

    func invalidate() {
        lineups = [:]
        generation += 1
    }
}

struct DailyArchiveView: View {
    @State private var viewModel = DailyArchiveViewModel()
    @State private var softWall: SoftWallContext?

    @Environment(Router.self) private var router
    @Environment(PremiumGate.self) private var premiumGate
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = themeStore.theme(for: colorScheme)
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.dateKeys.isEmpty {
                    Text("archive.empty", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.vertical, 60)
                }
                ForEach(viewModel.dateKeys, id: \.self) { dateKey in
                    ArchiveDayCard(
                        dateKey: dateKey,
                        lineup: viewModel.lineups[dateKey],
                        theme: theme,
                    ) { slot in
                        Task {
                            var canPlay = premiumGate.isPremium
                            if !canPlay {
                                canPlay = await viewModel.hasSavedGame(
                                    dateKey: dateKey,
                                    variant: slot.variant,
                                )
                            }
                            if canPlay {
                                router.play(GameLaunch(kind: .daily(
                                    dateKey: dateKey,
                                    variant: slot.variant,
                                    difficulty: slot.difficulty,
                                )))
                            } else {
                                softWall = SoftWallContext(variant: slot.variant)
                            }
                        }
                    }
                    .task(id: viewModel.generation) {
                        await viewModel.load(dateKey: dateKey)
                    }
                }
            }
            .padding(16)
        }
        .background(theme.screenBackground)
        .navigationTitle(Text("archive.title", bundle: .module))
        .onChange(of: router.game) { _, game in
            // The game cover doesn't refire row tasks underneath on its own.
            if game == nil {
                viewModel.invalidate()
            }
        }
        .sheet(item: $softWall) { context in
            SoftWallView(variant: context.variant)
        }
    }
}

/// One archived day: date header plus its three slots.
struct ArchiveDayCard: View {
    let dateKey: String
    let lineup: DailyLineup?
    let theme: Theme
    let onPlay: (DailyLineup.Slot) -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(dateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                if let lineup {
                    ForEach(lineup.slots, id: \.variant) { slot in
                        DailySlotRow(slot: slot, theme: theme) {
                            onPlay(slot)
                        }
                        if slot != lineup.slots.last {
                            Divider()
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
    }

    private var dateLabel: String {
        guard let date = EventSeeds.date(fromDateKey: dateKey) else { return dateKey }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}
