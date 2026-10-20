import SitRepPanel

/// The Notifications pane's words (DESIGN, "Settings"): the switch's line, saying what tells Lee of a new ask
/// instead while it is off, and macOS's own answer.
public enum NotificationsPane {
    /// The line under "Notify me of a new ask", for what shows at the edge.
    public static func switchLine(isOn: Bool, show: EdgeSettings.Show) -> String {
        let instead = switch show {
        case .notch: "the notch swells and lights"
        case .strip: "the strip flashes"
        case .nothing: "the menu bar's light comes on"
        }

        return isOn ? "On, and \(instead) as well" : "Off, \(instead) instead"
    }
}

/// What macOS lets SitRep do with notifications, as its own settings say.
public enum NoticeLeave: Equatable, Sendable {
    /// Not asked yet: macOS asks as the switch goes on, or at the first notification.
    case unasked
    case denied
    /// Allowed, delivered quietly to Notification Center until Lee says more.
    case provisional
    case allowed(Style)

    /// How an allowed notification shows.
    public enum Style: Sendable {
        case banners, alerts, none
    }

    /// In words, for the pane's "In System Settings" row.
    public var words: String {
        switch self {
        case .unasked: "Not asked yet: macOS asks once the switch is on"
        case .denied: "Not allowed"
        case .provisional: "Allowed quietly, in Notification Center"
        case .allowed(.banners): "Allowed, as banners"
        case .allowed(.alerts): "Allowed, as alerts"
        case .allowed(.none): "Allowed, but neither banners nor alerts show"
        }
    }
}
