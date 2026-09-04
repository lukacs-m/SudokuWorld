import Foundation
import Model
import Testing
@testable import Presentation

/// The learning section must cover every engine technique exactly once, in
/// rank order within its group, and every lesson string must exist in both
/// catalog languages. The catalog is read from the source tree because CLI
/// test hosts cannot resolve the compiled string table.
@Suite
@MainActor
struct LessonCatalogTests {
    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/Presentation/Resources/Localizable.xcstrings")

    private static let strings: [String: Any] = {
        let data = try? Data(contentsOf: catalogURL)
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        return json?["strings"] as? [String: Any] ?? [:]
    }()

    private static func isTranslated(_ key: String, in language: String) -> Bool {
        let entry = strings[key] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any]
        let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
        guard let value = unit?["value"] as? String else { return false }
        return unit?["state"] as? String == "translated" && !value.isEmpty
    }

    @Test func groupsCoverEveryTechniqueOnce() {
        let listed = LessonGroup.allCases.flatMap(\.techniques)
        #expect(listed.count == Technique.allCases.count)
        #expect(Set(listed) == Set(Technique.allCases))
    }

    @Test func groupsAreOrderedByRank() {
        for group in LessonGroup.allCases {
            let ranks = group.techniques.map(\.rank)
            #expect(ranks == ranks.sorted(), "\(group) is not in rank order")
        }
        #expect(LessonGroup.basics.techniques == [.nakedSingle, .hiddenSingle])
        #expect(LessonGroup.advanced.techniques == [.xWing, .swordfish, .xyWing, .xyChain])
    }

    @Test func catalogIsReadable() {
        #expect(!Self.strings.isEmpty, "could not read \(Self.catalogURL.path)")
    }

    @Test(arguments: Technique.allCases)
    func everyLessonStringExistsInEnglishAndFrench(technique: Technique) {
        let keys = ["definition", "where", "tip", "figure"].map {
            "learn.\(technique.rawValue).\($0)"
        } + ["technique.\(technique.rawValue)"]
        for key in keys {
            #expect(Self.isTranslated(key, in: "en"), "\(key) missing in en")
            #expect(Self.isTranslated(key, in: "fr"), "\(key) missing in fr")
        }
    }

    @Test func sectionAndEntryStringsExist() {
        let keys = [
            "learn.title", "home.learn", "home.learn.subtitle", "settings.learn", "hint.learnMore",
            "learn.group.basics", "learn.group.intermediate", "learn.group.advanced",
            "learn.group.variant", "learn.section.definition", "learn.section.example",
            "learn.section.where", "learn.section.tip", "learn.figure.legend.placement",
            "learn.figure.legend.eliminations",
        ]
        for key in keys {
            #expect(Self.isTranslated(key, in: "en"), "\(key) missing in en")
            #expect(Self.isTranslated(key, in: "fr"), "\(key) missing in fr")
        }
    }
}
