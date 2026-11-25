import Foundation

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

            /// What it wants, as the board and `sitrep answer --wants` say it.
            public var shape: Board.Ask.Wants {
                switch self {
                case .yes: .yes
                case .choice: .choice
                case .words: .words
                }
            }
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

        /// Why `words`, sent from this banner, cannot answer the ask as the board now holds it: Reply sent with none,
        /// or the ask reshaped since its banner showed, wanting something else, or no longer offering the words. Nil
        /// where they answer it, or where the board no longer holds it, which the CLI refuses in its own words.
        public func refusal(of words: String, live: Board.Ask?) -> String? {
            guard !words.isEmpty else {
                return "Reply had no words, so nothing was sent."
            }
            guard let live, !takes(words, live) else {
                return nil
            }

            return "The ask changed after its banner showed, so nothing was sent."
        }

        private func takes(_ words: String, _ live: Board.Ask) -> Bool {
            switch (wants, live.wants) {
            case (.yes, .yes): live.yes == words
            case (.choice, .choice): live.options.contains(words)
            case (.words, .words): true
            default: false
            }
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

    /// An answer or an ignore refused, said of its ask where the board named it: the words naming it by its title in
    /// place of its id, which Lee never sees, under its project and session, as its new ask's banner has them, a click
    /// jumping to its session. Named by nothing, in the words alone.
    public static func unanswered(_ why: String, of ask: AskNamed?) -> Banner {
        guard let ask else {
            return unanswered(why)
        }

        let id = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: ask.id))\\b")
        let title = NSRegularExpression.escapedTemplate(for: "“\(ask.title)”")
        let named = id?.stringByReplacingMatches(
            in: why, range: NSRange(why.startIndex..., in: why), withTemplate: title
        ) ?? why

        return Banner(title: "Not answered", subtitle: ask.place, body: named, work: ask.session)
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

/// An ask as a refusal's banner names it: its id, which the CLI's words name it by, its title, its project and
/// session, and its session, which a click jumps to.
public struct AskNamed: Equatable, Sendable {
    public let id: String
    public let title: String
    public let place: String
    public let session: String
}

extension Board {
    /// The ask of the session, named as its row shows it, in Needs you or, its whole session snoozed, in Snoozed; nil
    /// for an ask, or a session with no row, not on the board.
    public func naming(_ ask: String, of session: String) -> AskNamed? {
        let place = rows.first { $0.session == session }?.place ?? snoozed.first { $0.session == session }?.place

        guard let title = self.ask(ask, of: session)?.title, let place else {
            return nil
        }

        return AskNamed(id: ask, title: title, place: place, session: session)
    }
}

extension Board.SnoozedRow {
    /// Its project and session by name, as its row in Needs you says them.
    var place: String {
        "\(projectName) · \(name)"
    }
}

extension Board.Row {
    /// Its project and session by name, as a new ask's banner says them.
    public var place: String {
        "\(projectName) · \(name)"
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
