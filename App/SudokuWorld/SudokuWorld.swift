import Presentation
import SwiftUI

/// The entire app target. All logic and UI live in the layer packages
/// (Common / Model / Domain / Data / DI / Presentation); this file only
/// declares the entry point and hands off to the Presentation root.
@main
struct SudokuWorld: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
