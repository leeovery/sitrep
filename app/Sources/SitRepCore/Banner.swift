/// A banner's words, and the session clicking it jumps to, if any.
public struct Banner: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let body: String
    public let work: String?

    public init(title: String, subtitle: String?, body: String, work: String?) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.work = work
    }

    /// A jump that failed, in the CLI's words.
    public static func unjumped(_ why: String) -> Banner {
        refused("SitRep could not jump", why)
    }

    /// A jump that gave no answer in time: the caption's words, under the title that says it could not jump.
    public static let tooBusy = unjumped("The Mac is too busy to jump.")

    /// A snooze from a row's menu that the CLI refused, in its words, as the pane says it.
    public static func unsnoozed(_ why: String) -> Banner {
        refused("Not snoozed", why)
    }

    /// A row's Wake now that the CLI refused, in its words.
    public static func unwoken(_ why: String) -> Banner {
        refused("Not woken", why)
    }

    /// Something Lee chose that macOS refused, in its words.
    public static func refused(_ what: String, _ why: String) -> Banner {
        Banner(title: what, subtitle: nil, body: why, work: nil)
    }
}

extension JumpAnswer {
    /// The banner a jump that came to this posts: a refusal in the CLI's words, no answer in time as the Mac too busy;
    /// none for one that jumped, nor for one a later click stopped, as that one goes on.
    public var banner: Banner? {
        switch self {
        case .jumped, .stopped: nil
        case let .refused(why): .unjumped(why)
        case .unanswered: .tooBusy
        }
    }
}
