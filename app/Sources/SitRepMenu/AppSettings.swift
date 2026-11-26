import SitRepEdge
import SitRepPanel

/// What Lee sets beyond the edge, saved beside its settings as one value and read as leniently: for a new ask and for
/// his turn apart, whether it sends a notification, whether it plays a sound and which, and whether it pulses the
/// notch; how a window is opened for a session no terminal on this Mac shows, the terminal and the resume command;
/// whether SitRep has asked for the leave the panel's keys need; and the shortcut.
/// The keys from before his turn had its own (13 November 2026) are a new ask's still. A key another version saved, as
/// the Settings pane it last showed, or a setting retired since, as "Your turn folds after" (4 November 2026) and the
/// open command (13 November 2026), is passed over.
public struct AppSettings: SavedValue {
    public static let key = "app"

    /// Off by default, since the notch swells and lights for a new ask (DESIGN, "The menu bar").
    public var notifiesNewAsks = false
    /// On by default, as the sound played from each window before SitRep played it (DESIGN, "Settings").
    public var playsSound = true
    /// One of macOS's alert sounds, by name, as saved: `AlertSounds` reads one macOS lacks as Glass, the one the
    /// windows played, and the default.
    public var sound = "Glass"
    /// On by default, as the notch swelled for every new ask before it was a setting.
    public var pulsesNewAsks = true
    /// Lee's turn's, each off by default: the notch's light, blue while a turn waits, says it already.
    public var notifiesTurns = false
    public var playsTurnSound = false
    /// Another sound than a new ask's, so the two are told apart by ear.
    public var turnSound = "Tink"
    public var pulsesTurns = false
    /// The terminal a window for a session no terminal on this Mac shows opens in, by its `$TERM_PROGRAM`
    /// (`Driver.program`): Ghostty, the one with a driver.
    public var terminal = "ghostty"
    /// The command typed in that window, as Lee gives it, empty where he cleared it; nil until he gives one, which reads
    /// as the default. Saved under a key of its own, `resume`: Settings saves every field, so the `resumeCommand` saved
    /// before it, empty where it was never set, is read only where it holds a command.
    public var resumeCommand: String?
    /// Whether SitRep has asked macOS for the Accessibility leave the notch's panel takes keys with, as Settings' Allow…
    /// does: macOS keeps no "not asked yet" for it, so SitRep keeps that it asked.
    public var askedForKeys = false
    /// The hot key that opens the notch's panel, or the menu bar's menu (DESIGN, "Keys"): ⌃⌥S unless Lee set another
    /// or cleared it.
    public var shortcut = Shortcut.standard

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
        pulsesNewAsks = given.value(.pulsesNewAsks, or: defaults.pulsesNewAsks)
        notifiesTurns = given.value(.notifiesTurns, or: defaults.notifiesTurns)
        playsTurnSound = given.value(.playsTurnSound, or: defaults.playsTurnSound)
        turnSound = given.value(.turnSound, or: defaults.turnSound)
        pulsesTurns = given.value(.pulsesTurns, or: defaults.pulsesTurns)
        terminal = given.value(.terminal, or: defaults.terminal)
        resumeCommand = given.value(.resumeCommand, or: Self.retiredResumeCommand(in: decoder))
        askedForKeys = given.value(.askedForKeys, or: defaults.askedForKeys)
        shortcut = given.value(.shortcut, or: defaults.shortcut)
    }

    private enum CodingKeys: String, CodingKey {
        case notifiesNewAsks, playsSound, sound, pulsesNewAsks, notifiesTurns, playsTurnSound, turnSound, pulsesTurns
        case terminal
        case resumeCommand = "resume"
        case askedForKeys, shortcut
    }

    /// What pulses the notch as it comes, as Lee set it.
    public var pulses: Set<Need> {
        Set(Need.allCases.filter { $0 == .ask ? pulsesNewAsks : pulsesTurns })
    }

    /// Whether a new ask, or Lee's turn, sends a notification, as he set it.
    public func notifies(_ need: Need) -> Bool {
        need == .ask ? notifiesNewAsks : notifiesTurns
    }

    /// The sound a new ask, or Lee's turn, plays, as saved.
    public func sound(for need: Need) -> String {
        need == .ask ? sound : turnSound
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
