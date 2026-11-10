import SitRepEdge
import SitRepPanel

/// What Lee sets beyond the edge, saved beside its settings as one value and read as leniently: whether a new ask
/// sends a notification, and whether it plays a sound and which; and how a window is opened for a session no window
/// shows, the terminal and the command. A key another version saved, as the Settings pane it
/// last showed, or a setting retired since, as "Your turn folds after" (4 November 2026), is passed over.
public struct AppSettings: SavedValue {
    public static let key = "app"

    /// Off by default, since the notch swells and lights for a new ask (DESIGN, "The menu bar").
    public var notifiesNewAsks = false
    /// On by default, as the sound played from each window before SitRep played it (DESIGN, "Settings").
    public var playsSound = true
    /// One of macOS's alert sounds, by name, as saved: `AlertSounds` reads one macOS lacks as Glass, the one the
    /// windows played, and the default.
    public var sound = "Glass"
    /// The terminal a window for a session no window shows opens in, by its `$TERM_PROGRAM` (`Driver.program`):
    /// Ghostty, the one with a driver.
    public var terminal = "ghostty"
    /// The command run in that window, as Lee gives it: empty until he does, as SitRep has no built-in way to attach.
    public var openCommand = ""

    public init() {}

    public init(from decoder: any Decoder) {
        let defaults = AppSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        notifiesNewAsks = given.value(.notifiesNewAsks, or: defaults.notifiesNewAsks)
        playsSound = given.value(.playsSound, or: defaults.playsSound)
        sound = given.value(.sound, or: defaults.sound)
        terminal = given.value(.terminal, or: defaults.terminal)
        openCommand = given.value(.openCommand, or: defaults.openCommand)
    }
}
