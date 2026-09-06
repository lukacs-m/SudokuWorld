import Model
import Testing
@testable import Presentation

@Suite
struct GameLaunchTests {
    @Test func newGameOnAHiddenTierSnapsToTheNearestOfferedTier() {
        let launch = GameLaunch(kind: .new(variant: .tredoku, difficulty: .expert, mode: .normal))
        #expect(launch.kind == .new(variant: .tredoku, difficulty: .hard, mode: .normal))
    }

    @Test func newGameOnAnOfferedTierIsUntouched() {
        let launch = GameLaunch(kind: .new(variant: .classic, difficulty: .master, mode: .hardcore))
        #expect(launch.kind == .new(variant: .classic, difficulty: .master, mode: .hardcore))
    }

    @Test func dailyAndWeeklyLaunchesAreNotRewritten() {
        let daily = GameLaunch(kind: .daily(dateKey: "2026-01-10", variant: .tredoku, difficulty: .expert))
        #expect(daily.kind == .daily(dateKey: "2026-01-10", variant: .tredoku, difficulty: .expert))
        let weekly = GameLaunch(kind: .weekly(variant: .cube, difficulty: .master))
        #expect(weekly.kind == .weekly(variant: .cube, difficulty: .master))
    }
}
