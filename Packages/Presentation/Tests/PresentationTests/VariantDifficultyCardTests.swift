import Foundation
import Model
import SwiftUI
import Testing

@testable import Presentation

/// The deep dive's per-difficulty times are analysis, so the card is a
/// premium preview: blurred with a lock for free players, the plain rows
/// for premium ones. The gate is read from the environment, as everywhere.
@MainActor
struct VariantDifficultyCardTests {
    private let cells: [VariantStats] = [
        VariantStats(
            variant: .killer,
            difficulty: .easy,
            played: 3,
            won: 2,
            lost: 1,
            abandoned: 0,
            currentWinStreak: 0,
            bestWinStreak: 0,
            fastestTime: 245,
            averageTime: 310,
            perfectSolves: 1,
        ),
        VariantStats(
            variant: .killer,
            difficulty: .medium,
            played: 0,
            won: 0,
            lost: 0,
            abandoned: 0,
            currentWinStreak: 0,
            bestWinStreak: 0,
            fastestTime: nil,
            averageTime: nil,
            perfectSolves: 0,
        ),
    ]

    @Test func theCardIsThePremiumBlurWrapper() {
        let body = VariantDifficultyCard(cells: cells).body

        #expect(String(describing: type(of: body)).hasPrefix("PremiumStatBlurOverlay<"))
    }

    @Test func freePlayersGetTheLockedPreview() throws {
        let free = try #require(render(VariantDifficultyCard(cells: cells), isPremium: false))
        let premium = try #require(render(VariantDifficultyCard(cells: cells), isPremium: true))

        #expect(free != premium)
    }

    @Test func premiumPlayersGetTheRowsUntouched() throws {
        let card = try #require(render(VariantDifficultyCard(cells: cells), isPremium: true))
        let rows = try #require(render(CardView { VariantDifficultyRows(cells: cells) }, isPremium: true))

        #expect(card == rows)
    }

    private func render(_ view: some View, isPremium: Bool) -> Data? {
        let renderer = ImageRenderer(content: view
            .frame(width: 390)
            .environment(ThemeStore())
            .environment(PremiumGate(isPremium: isPremium)))
        renderer.scale = 1
        return renderer.cgImage?.dataProvider?.data as Data?
    }
}
