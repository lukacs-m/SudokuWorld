/// Player-tunable gameplay preferences, persisted as one value.
public struct GameSettings: Equatable, Sendable, Codable {
    public var inputMode: InputMode
    /// Placing a value wipes that digit from peer-cell notes.
    public var autoCleanNotes: Bool
    /// Tint entries that contradict the solution.
    public var mistakeHighlighting: Bool
    /// Continuously verify entries as they are placed.
    public var autoCheck: Bool
    public var hapticsEnabled: Bool
    public var timerVisible: Bool
    /// New games start in hardcore mode (limited mistakes, no hints).
    public var hardcoreByDefault: Bool
    public var theme: ThemeID

    public static let standard = Self(
        inputMode: .cellFirst,
        autoCleanNotes: true,
        mistakeHighlighting: true,
        autoCheck: false,
        hapticsEnabled: true,
        timerVisible: true,
        hardcoreByDefault: false,
        theme: .classicBlue,
    )

    public init(
        inputMode: InputMode,
        autoCleanNotes: Bool,
        mistakeHighlighting: Bool,
        autoCheck: Bool,
        hapticsEnabled: Bool,
        timerVisible: Bool,
        hardcoreByDefault: Bool,
        theme: ThemeID,
    ) {
        self.inputMode = inputMode
        self.autoCleanNotes = autoCleanNotes
        self.mistakeHighlighting = mistakeHighlighting
        self.autoCheck = autoCheck
        self.hapticsEnabled = hapticsEnabled
        self.timerVisible = timerVisible
        self.hardcoreByDefault = hardcoreByDefault
        self.theme = theme
    }
}
