import Foundation

/// A banner's words, the session clicking it jumps to, if any, and the new ask it tells of, if any.
public struct Banner: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let body: String
    public let work: String?
    /// The new ask it tells of, by which it is taken down once the ask waits on Lee no more; nil for every other
    /// banner.
    public let ask: AskOf?

    public init(title: String, subtitle: String?, body: String, work: String?, ask: AskOf? = nil) {
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

/// A row of a session, named by its project and its session.
public protocol Placed {
    var projectName: String { get }
    var name: String { get }
}

extension Placed {
    /// Its project and session by name, as a new ask's banner says them, from its row in Needs you or in Snoozed alike.
    public var place: String {
        "\(projectName) · \(name)"
    }
}

extension Board.Row: Placed {}

extension Board.SnoozedRow: Placed {}

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
