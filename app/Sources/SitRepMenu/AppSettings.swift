import SitRepEdge
import SitRepPanel

/// What Lee sets beyond the edge, saved beside its settings as one value and read as leniently: whether a new ask
/// sends a notification, and whether it plays a sound and which; and how a window is opened for a session no terminal
/// on this Mac shows, the terminal and the resume command. A key another version saved, as the Settings pane it last
/// showed, or a setting retired since, as "Your turn folds after" (4 November 2026) and the open command (13 November
/// 2026), is passed over.
public struct AppSettings: SavedValue {
    public static let key = "app"

    /// Off by default, since the notch swells and lights for a new ask (DESIGN, "The menu bar").
    public var notifiesNewAsks = false
    /// On by default, as the sound played from each window before SitRep played it (DESIGN, "Settings").
    public var playsSound = true
    /// One of macOS's alert sounds, by name, as saved: `AlertSounds` reads one macOS lacks as Glass, the one the
    /// windows played, and the default.
    public var sound = "Glass"
    /// The terminal a window for a session no terminal on this Mac shows opens in, by its `$TERM_PROGRAM`
    /// (`Driver.program`): Ghostty, the one with a driver.
    public var terminal = "ghostty"
    /// The command typed in that window, as Lee gives it, empty where he cleared it; nil until he gives one, which reads
    /// as the default. Saved under a key of its own, `resume`: Settings saves every field, so the `resumeCommand` saved
    /// before it, empty where it was never set, is read only where it holds a command.
    public var resumeCommand: String?

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
        resumeCommand = given.value(.resumeCommand, or: Self.retiredResumeCommand(in: decoder))
    }

    private enum CodingKeys: String, CodingKey {
        case notifiesNewAsks, playsSound, sound, terminal
        case resumeCommand = "resume"
    }

    /// The resume command as saved before it had a key of its own: none where it was empty, as it was until Lee gave one.
    private static func retiredResumeCommand(in decoder: any Decoder) -> String? {
        let saved = try? decoder.container(keyedBy: Retired.self).value(.resumeCommand, or: "")

        return saved?.isEmpty == false ? saved : nil
    }

    private enum Retired: String, CodingKey {
        case resumeCommand
    }
}
