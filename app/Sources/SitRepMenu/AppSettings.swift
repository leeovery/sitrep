import SitRepEdge
import SitRepPanel

/// What Lee sets beyond the edge, saved beside its settings as one value and read as leniently: whether a new ask
/// sends a notification, and the Settings pane ⌘, opens on.
public struct AppSettings: SavedValue {
    public static let key = "app"

    /// Off by default, since the notch swells and lights for a new ask (DESIGN, "The menu bar").
    public var notifiesNewAsks = false
    /// The pane last used.
    public var pane = SettingsPane.edge

    public init() {}

    public init(from decoder: any Decoder) {
        let defaults = AppSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        notifiesNewAsks = given.value(.notifiesNewAsks, or: defaults.notifiesNewAsks)
        pane = given.value(.pane, or: defaults.pane)
    }
}

/// The Settings window's three panes, the edge first, since it is what SitRep is.
public enum SettingsPane: String, Codable, CaseIterable, Sendable, Identifiable {
    case edge, notifications, general

    public var id: Self { self }

    public var title: String {
        switch self {
        case .edge: "At the edge"
        case .notifications: "Notifications"
        case .general: "General"
        }
    }

    /// Its SF Symbol in the sidebar.
    public var symbol: String {
        switch self {
        case .edge: "rectangle.leadinghalf.inset.filled"
        case .notifications: "bell"
        case .general: "gearshape"
        }
    }
}
