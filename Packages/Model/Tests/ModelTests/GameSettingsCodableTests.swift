import Foundation
import Testing
@testable import Model

/// Settings persist as one JSON blob, so fields added after 1.0 must decode
/// from payloads that predate them.
@Suite
struct GameSettingsCodableTests {
    /// A faithful pre-`appearance` payload, with the persisted raw value of
    /// the original default theme slot.
    private let legacyJSON = """
    {
      "inputMode": "cellFirst",
      "autoCleanNotes": true,
      "mistakeHighlighting": true,
      "autoCheck": false,
      "hapticsEnabled": true,
      "timerVisible": true,
      "hardcoreByDefault": false,
      "theme": "classicBlue"
    }
    """

    @Test func legacyPayloadsDecode() throws {
        let settings = try JSONDecoder().decode(
            GameSettings.self,
            from: Data(legacyJSON.utf8),
        )
        #expect(settings.theme == .warmPaper)
        #expect(settings.appearance == nil)
    }

    @Test func appearanceRoundTrips() throws {
        var settings = GameSettings.standard
        settings.appearance = .dark
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(GameSettings.self, from: data)
        #expect(decoded.appearance == .dark)
    }
}
