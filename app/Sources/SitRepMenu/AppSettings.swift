import SitRepEdge
import SitRepPanel

/// What Lee sets beyond the edge, saved beside its settings as one value and read as leniently: whether a new ask
/// sends a notification, and how long a your-turn row stays before it folds into "N earlier". A key another version
/// saved, as the Settings pane it last showed, is passed over.
public struct AppSettings: SavedValue {
    public static let key = "app"

    /// Off by default, since the notch swells and lights for a new ask (DESIGN, "The menu bar").
    public var notifiesNewAsks = false
    /// An hour by default (DESIGN, "Settings").
    public var foldsAfter = FoldPeriod.hour

    public init() {}

    public init(from decoder: any Decoder) {
        let defaults = AppSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        notifiesNewAsks = given.value(.notifiesNewAsks, or: defaults.notifiesNewAsks)
        foldsAfter = given.value(.foldsAfter, or: defaults.foldsAfter)
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
