public import Model
import SwiftUI

/// Every sheet the app presents, built in `sheetDestinations(_:)`.
public enum SheetDestination: Hashable, Identifiable {
    public var id: Self {
        self
    }

    case newGame
    case rules(SudokuVariant)
    case softWall(SudokuVariant)
    case paywall
    case lesson(Technique)
}

/// Every full-screen cover, built in `fullScreenDestination(_:)`.
public enum FullScreenDestination: Hashable, Identifiable {
    public var id: Self {
        self
    }

    case game(GamePresentation)
}

extension View {
    /// The one place sheets are built (except the hint sheet, see
    /// `docs/ARCHITECTURE.md`). The root binds `AppRouter.presentedSheet`;
    /// a modal that presents a sheet of its own binds a local `presentedSheet`
    /// instead, because a modal can only present from its own hierarchy.
    func sheetDestinations(_ destination: Binding<SheetDestination?>) -> some View {
        sheet(item: destination) { destination in
            switch destination {
            case .newGame:
                NewGameSheet()
            case let .rules(variant):
                VariantRulesView(variant: variant)
            case let .softWall(variant):
                SoftWallView(variant: variant)
            case .paywall:
                PaywallView()
            case let .lesson(technique):
                LessonSheet(technique: technique)
            }
        }
    }

    /// The game cover; a sheet on macOS, which has no `fullScreenCover`
    /// (test builds only).
    func fullScreenDestination(_ destination: Binding<FullScreenDestination?>) -> some View {
        #if os(iOS)
            fullScreenCover(item: destination) { destination in
                FullScreenDestinationView(destination: destination)
            }
        #else
            sheet(item: destination) { destination in
                FullScreenDestinationView(destination: destination)
            }
        #endif
    }
}

private struct FullScreenDestinationView: View {
    let destination: FullScreenDestination

    var body: some View {
        switch destination {
        case let .game(presentation):
            GameStack(launch: presentation.launch)
        }
    }
}
