import SitRepEdge
import SitRepPanel

/// What Lee sets beyond the edge, saved beside its settings as one value and read as leniently: whether a new ask
/// sends a notification, whether it plays a sound and which, how long a your-turn row stays before it folds into
/// "N earlier", and the pane the Settings window last showed. A key another version saved is passed over.
public struct AppSettings: SavedValue {
    public static let key = "app"

    /// Off by default, since the notch swells and lights for a new ask (DESIGN, "The menu bar").
    public var notifiesNewAsks = false
    /// On by default, as the sound played from each window before SitRep played it (DESIGN, "Settings").
    public var playsSound = true
    /// One of macOS's alert sounds, by name, as saved: `AlertSounds` reads one macOS lacks as Glass, the one the
    /// windows played, and the default.
    public var sound = "Glass"
    /// An hour by default (DESIGN, "Settings").
    public var foldsAfter = FoldPeriod.hour
    /// The pane the Settings window opens on: the one it last showed, General the first time. Round 5's window saved
    /// its own under this key, its edge, notifications and general read as these panes.
    public var pane = SettingsPane.general

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
        foldsAfter = given.value(.foldsAfter, or: defaults.foldsAfter)
        pane = given.value(.pane, or: defaults.pane)
    }
}

extension FoldPeriod {
    /// As Settings' pop-up names it.
    public var title: String {
        switch self {
        case .hour: "An hour"
        case .fourHours: "Four hours"
        case .today: "Today"
        case .never: "Never"
        }
    }
}
