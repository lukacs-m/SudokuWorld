#if DEBUG
    import DI
    import Domain
    import Model
    import SwiftUI

    /// Debug-only tooling: the full Game Center ID matrix (for App Store Connect
    /// setup), achievement reset, and a deterministic-seed playground.
    struct DebugMenuView: View {
        @State private var resetResult: String?

        @Environment(Router.self) private var router

        var body: some View {
            List {
                Section("Leaderboards (\(GameCenterIDs.allLeaderboardIDs.count))") {
                    ForEach(GameCenterIDs.allLeaderboardIDs, id: \.self) { id in
                        Text(id)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Section("Achievements (\(GameCenterIDs.Achievement.allCases.count))") {
                    ForEach(GameCenterIDs.Achievement.allCases, id: \.rawValue) { achievement in
                        HStack {
                            Text(achievement.id)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Spacer()
                            Text("\(achievement.points)pt")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Actions") {
                    Button("Reset achievements", role: .destructive) {
                        Task {
                            // Bound to a local first: chaining resolution and the
                            // callAsFunction crashes the Swift 6.3 SILGen.
                            let resetAchievements = Container.shared.resetAchievementsUseCase()
                            do {
                                try await resetAchievements()
                                resetResult = "Achievements reset."
                            } catch {
                                resetResult = "Reset failed: \(error)"
                            }
                        }
                    }
                    if let resetResult {
                        Text(resetResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Quick play (medium)") {
                    ForEach(SudokuVariant.allCases, id: \.self) { variant in
                        Button("Play \(variant.slug)") {
                            router.play(GameLaunch(kind: .new(
                                variant: variant,
                                difficulty: .medium,
                                mode: .normal,
                            )))
                        }
                    }
                    Text(
                        "Regular games derive their seed from the start time; "
                            + "only the daily challenge replays deterministically.",
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Debug")
        }
    }
#endif
