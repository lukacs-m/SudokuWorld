import Model
import Testing
@testable import Presentation

@Suite
@MainActor
struct VariantCatalogTests {
    @Test func cubeIsListedUnderTwistsWithTheNewBadge() {
        #expect(VariantCatalog.available.contains(.cube))
        let twists = VariantCatalog.sections.first { $0.group == .twists }
        #expect(twists?.variants.contains(.cube) == true)
        #expect(VariantCatalog.badge(for: .cube) == .new)
        #expect(VariantCatalog.badge(for: .classic) == .popular)
    }

    @Test func everyVariantAppearsInExactlyOneSection() {
        let listed = VariantCatalog.sections.flatMap(\.variants)
        #expect(listed.count == SudokuVariant.allCases.count)
        #expect(Set(listed) == Set(SudokuVariant.allCases))
    }
}
