/// A banner's words, the session clicking it jumps to, if any, and the ask its buttons answer, if any.
public struct Banner: Equatable, Sendable {
    /// An ask a new ask's banner answers with the buttons macOS draws (DESIGN, "The menu bar", "Its buttons"): its id,
    /// its session, and what it wants back.
    public struct Ask: Equatable, Sendable {
        public enum Wants: Equatable, Sendable {
            /// One button, its yes.
            case yes(String)
            /// A button for each option, in Claude's order.
            case choice([String])
            /// Reply, macOS's text field, with Send.
            case words
        }

        public let id: String
        public let session: String
        public let wants: Wants

        public init(id: String, session: String, wants: Wants) {
            self.id = id
            self.session = session
            self.wants = wants
        }

        /// The board's ask, as its banner answers it; nil for a choice with no options to choose from, whose banner
        /// has no buttons.
        public init?(_ ask: Board.Ask, of session: String) {
            switch (ask.wants, ask.yes) {
            case let (.yes, yes?): wants = .yes(yes)
            case (.choice, _) where !ask.options.isEmpty: wants = .choice(ask.options)
            case (.words, _): wants = .words
            default: return nil
            }

            id = ask.id
            self.session = session
        }
    }

    public let title: String
    public let subtitle: String?
    public let body: String
    public let work: String?
    /// The ask its buttons answer; nil for every other banner, which has none.
    public let ask: Ask?

    public init(title: String, subtitle: String?, body: String, work: String?, ask: Ask? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.work = work
        self.ask = ask
    }

    /// A jump that failed, in the words of its refusal.
    public static func unjumped(_ why: String) -> Banner {
        refused("SitRep could not jump", why)
    }

    /// A jump that gave no answer in time: the caption's words, under the title that says it could not jump.
    public static let tooBusy = unjumped("The Mac is too busy to jump.")

    /// A window for a session no terminal on this Mac shows that could not be opened, in the words of its refusal, which
    /// name the session.
    public static func unopened(_ why: String) -> Banner {
        refused("SitRep could not open a window", why)
    }

    /// A click that took Lee to a window and started nothing there, saying why.
    public static func startedNothing(_ why: String) -> Banner {
        refused("SitRep started nothing", why)
    }

    /// A snooze from a row's menu that the CLI refused, in its words, as the pane says it.
    public static func unsnoozed(_ why: String) -> Banner {
        refused("Not snoozed", why)
    }

    /// An answer or an ignore that the CLI refused, in its words, as for an ask answered in its window meanwhile.
    public static func unanswered(_ why: String) -> Banner {
        refused("Not answered", why)
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
    /// The banner a jump that came to this posts: a refusal in its own words, a window's under its own title; no
    /// answer in time as the Mac too busy; a window brought forward with a word for Lee, that word; none for one that
    /// jumped or opened a window, nor for one a later click stopped, as that one goes on.
    public var banner: Banner? {
        switch self {
        case .jumped, .openable, .opened, .opening, .stopped: nil
        case let .jumpedSaying(why): .startedNothing(why)
        case let .refused(why): .unjumped(why)
        case let .unopened(why): .unopened(why)
        case .unanswered: .tooBusy
        }
    }

    /// Whether the front goes back to the app in front before the click: nothing came forward, as for a refusal, or a
    /// window is still opening.
    public var handsBack: Bool {
        switch self {
        case .refused, .unopened, .unanswered, .opening: true
        case .jumped, .jumpedSaying, .openable, .opened, .stopped: false
        }
    }
}
