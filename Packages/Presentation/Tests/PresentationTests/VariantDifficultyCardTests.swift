import CoreGraphics
import Foundation
import Model
import SwiftUI
import Testing

@testable import Presentation

/// The deep dive's per-difficulty won / played counts are motivation and stay
/// free; the best and average times beside them are analysis, so free players
/// get those blurred under the lock. Premium players get the plain rows.
@MainActor
struct VariantDifficultyCardTests {
    /// Two renders of the same content still land a level apart on
    /// anti-aliased edges; a blurred column is nowhere near that close.
    private static let sameContent = 2
    private static let blurredContent = 64

    private let touched = VariantStats(
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
    )

    private let untouched = VariantStats(
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
    )

    private let neverWon = VariantStats(
        variant: .killer,
        difficulty: .easy,
        played: 2,
        won: 0,
        lost: 2,
        abandoned: 0,
        currentWinStreak: 0,
        bestWinStreak: 0,
        fastestTime: nil,
        averageTime: nil,
        perfectSolves: 0,
    )

    private var cells: [VariantStats] { [touched, untouched] }

    /// Both gates lay the rows out identically from the top of the card - the
    /// lock only adds its label below them - so one band covers the same rows
    /// in either render: counts on its left, times on its right.
    @Test func freePlayersKeepTheirCountsAndLoseTheirTimes() throws {
        let free = try #require(render(VariantDifficultyCard(cells: cells), isPremium: false))
        let premium = try #require(render(VariantDifficultyCard(cells: cells), isPremium: true))
        let rows = CGFloat(premium.height) * 2 / 3
        let half = CGFloat(premium.width) / 2
        let counts = CGRect(x: 0, y: 0, width: half, height: rows)
        let times = CGRect(x: half, y: 0, width: half, height: rows)

        #expect(try largestDifference(free, premium, in: counts) <= Self.sameContent)
        #expect(try largestDifference(free, premium, in: times) > Self.blurredContent)
    }

    /// A variant the player has played but never finished has no time to
    /// hide, so the lock would sell nothing: free players get the very card
    /// premium players get, with no lock label and nothing to tap.
    @Test func aVariantWithNoTimeGetsNoLock() throws {
        let free = try #require(render(VariantDifficultyCard(cells: [neverWon]), isPremium: false))
        let premium = try #require(render(VariantDifficultyCard(cells: [neverWon]), isPremium: true))

        try #require(free.width == premium.width)
        try #require(free.height == premium.height)
        #expect(try largestDifference(free, premium, in: bounds(of: free)) <= Self.sameContent)
    }

    /// Inside a locked card, a tier with no game finished has no premium
    /// value behind the blur, so its dashes stay sharp.
    @Test func tiersWithoutATimeAreNotBlurred() throws {
        let locked = try #require(render(
            CardView { VariantDifficultyRows(cells: [untouched], timesBlurred: true) },
            isPremium: false,
        ))
        let plain = try #require(render(CardView { VariantDifficultyRows(cells: [untouched]) }, isPremium: false))

        try #require(locked.height == plain.height)
        #expect(try largestDifference(locked, plain, in: bounds(of: plain)) <= Self.sameContent)
    }

    @Test func premiumPlayersGetTheRowsUntouched() throws {
        let card = try #require(render(VariantDifficultyCard(cells: cells), isPremium: true))
        let rows = try #require(render(CardView { VariantDifficultyRows(cells: cells) }, isPremium: true))

        try #require(card.width == rows.width)
        try #require(card.height == rows.height)
        #expect(try largestDifference(card, rows, in: bounds(of: card)) <= Self.sameContent)
    }

    private func render(_ view: some View, isPremium: Bool) -> CGImage? {
        let renderer = ImageRenderer(content: view
            .frame(width: 390)
            .environment(AppRouter())
            .environment(ThemeStore())
            .environment(PremiumGate(isPremium: isPremium)))
        renderer.scale = 1
        return renderer.cgImage
    }

    private func largestDifference(_ lhs: CGImage, _ rhs: CGImage, in rect: CGRect) throws -> Int {
        let left = try pixels(lhs, in: rect)
        let right = try pixels(rhs, in: rect)
        try #require(left.count == right.count)
        return zip(left, right).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }

    /// `CGImage.cropping` may hand back the parent's whole buffer, so the
    /// region is redrawn into its own context before its bytes are read.
    private func pixels(_ image: CGImage, in rect: CGRect) throws -> Data {
        let region = try #require(image.cropping(to: rect))
        let context = try #require(CGContext(
            data: nil,
            width: region.width,
            height: region.height,
            bitsPerComponent: 8,
            bytesPerRow: region.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ))
        context.draw(region, in: bounds(of: region))
        let bytes = try #require(context.data)
        return Data(bytes: bytes, count: context.bytesPerRow * region.height)
    }

    private func bounds(of image: CGImage) -> CGRect {
        CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }
}
