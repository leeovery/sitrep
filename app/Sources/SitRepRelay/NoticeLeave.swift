/// What macOS lets SitRep do with notifications, as its own settings for the notices helper say.
public enum NoticeLeave: Equatable, Sendable {
    /// Not asked yet: macOS asks as the switch goes on, or at the first notification.
    case unasked
    case denied
    /// Allowed, delivered quietly to Notification Center until Lee says more.
    case provisional
    case allowed(Style)

    /// How an allowed notification shows.
    public enum Style: Sendable, CaseIterable {
        case banners, alerts, none
    }

    /// Every leave there is.
    public static let all: [NoticeLeave] = [.unasked, .denied, .provisional] + Style.allCases.map(allowed)
}

extension NoticeLeave {
    /// Its word in a letter.
    var word: String {
        switch self {
        case .unasked: "unasked"
        case .denied: "denied"
        case .provisional: "provisional"
        case .allowed(.banners): "banners"
        case .allowed(.alerts): "alerts"
        case .allowed(.none): "unshown"
        }
    }

    init?(word: String) {
        guard let leave = Self.all.first(where: { $0.word == word }) else {
            return nil
        }

        self = leave
    }
}
