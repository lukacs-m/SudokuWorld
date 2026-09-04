import Model
import SwiftUI

/// The learning section's table of contents: every engine technique, grouped
/// by difficulty band and ordered by spotting rank within each group.
/// Lesson copy lives in the string catalog under `learn.<technique>.*`; the
/// technique names are the same `technique.*` strings the hint sheet uses.
enum LessonGroup: CaseIterable {
    case basics
    case intermediate
    case advanced
    case variantSpecific

    var titleKey: LocalizedStringKey {
        switch self {
        case .basics: "learn.group.basics"
        case .intermediate: "learn.group.intermediate"
        case .advanced: "learn.group.advanced"
        case .variantSpecific: "learn.group.variant"
        }
    }

    /// Ties (cage and arrow arithmetic share a rank) break on declaration
    /// order — `sorted(by:)` is not guaranteed stable, so the index is part
    /// of the comparison rather than an assumption about the sort.
    var techniques: [Technique] {
        Technique.allCases
            .filter { $0.lessonGroup == self }
            .enumerated()
            .sorted { ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset) }
            .map(\.element)
    }
}

extension Technique {
    var lessonGroup: LessonGroup {
        switch self {
        case .nakedSingle, .hiddenSingle:
            .basics
        case .nakedPair, .hiddenPair, .pointingPair, .boxLineReduction, .nakedTriple, .hiddenTriple:
            .intermediate
        case .xWing, .swordfish, .xyWing, .xyChain:
            .advanced
        case .cageArithmetic, .relationAnalysis, .arrowArithmetic, .outsideClueAnalysis:
            .variantSpecific
        }
    }

    var lessonName: String {
        moduleString("technique.\(rawValue)")
    }

    /// One of `definition`, `where`, `tip`, `figure`.
    func lessonText(_ part: String) -> String {
        moduleString("learn.\(rawValue).\(part)")
    }
}
