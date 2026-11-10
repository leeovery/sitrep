import SitRepEdge
import SitRepPanel

/// What Lee sets beyond the edge, saved beside its settings as one value and read as leniently: whether a new ask
/// sends a notification, and whether it plays a sound and which. A key another version saved, as the Settings pane it
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
    /// The commands typed into a new Ghostty window for a session no window shows, attaching to its zmx session or its
    /// tmux pane, as Lee gives them; empty for SitRep's own (`AttachCommands`).
    public var zmxAttach = ""
    public var tmuxAttach = ""

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
        zmxAttach = given.value(.zmxAttach, or: defaults.zmxAttach)
        tmuxAttach = given.value(.tmuxAttach, or: defaults.tmuxAttach)
    }
}
