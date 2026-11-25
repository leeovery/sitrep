/// What one side of the relay says to the other, as the plist of strings a distributed notification carries.
public protocol Relayed: Equatable, Sendable {
    /// The way it goes: the last part of its name, under the helper's bundle id.
    static var way: String { get }
    var fields: [String: String] { get }
    init?(fields: [String: String])
}

/// A message and SitRep's pid, whichever way it goes: the SitRep the helper serves. Each side reads only the letters
/// of its own SitRep, so a helper left over from another, or a helper serving another, is not heard.
public struct Letter<Message: Relayed>: Equatable, Sendable {
    public let message: Message
    public let pid: Int32

    public init(_ message: Message, pid: Int32) {
        self.message = message
        self.pid = pid
    }

    /// Nil for anything not a letter: missing its pid, or a message not known.
    public init?(userInfo: [AnyHashable: Any]?) {
        guard
            let fields = userInfo as? [String: String],
            let pid = fields[Self.pidKey].flatMap(Int32.init),
            let message = Message(fields: fields)
        else {
            return nil
        }

        self.init(message, pid: pid)
    }

    public var userInfo: [String: String] {
        message.fields.merging([Self.pidKey: String(pid)]) { _, pid in pid }
    }

    /// The message, when it is the SitRep with this pid's; nil when it is another's.
    public func message(for pid: Int32) -> Message? {
        self.pid == pid ? message : nil
    }

    private static var pidKey: String { "pid" }
}

/// A banner to post: its words, the session a click on it jumps to, if any, and the ask it tells of, if any.
public struct Notice: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let body: String
    public let work: String?
    /// The new ask it tells of, by which it is taken down once the ask waits on Lee no more; nil for every other
    /// banner.
    public let ask: NoticeAsk?

    public init(title: String, subtitle: String?, body: String, work: String?, ask: NoticeAsk? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.work = work
        self.ask = ask
    }

    var fields: [String: String] {
        ["title": title, "subtitle": subtitle, "body": body, "work": work].compactMapValues { $0 }
            .merging(ask?.fields ?? [:]) { notice, _ in notice }
    }

    /// An ask that does not read leaves the banner telling of none.
    init?(fields: [String: String]) {
        guard let title = fields["title"], let body = fields["body"] else {
            return nil
        }

        self.init(
            title: title, subtitle: fields["subtitle"], body: body, work: fields["work"], ask: NoticeAsk(fields: fields)
        )
    }
}

/// The ask a new ask's banner tells of, by its id and its session's. Its fields go in the post, and in the banner's
/// userInfo, which the helper reads back to find the banners of an ask that waits on Lee no more.
public struct NoticeAsk: Equatable, Sendable {
    public let id: String
    public let session: String

    public init(id: String, session: String) {
        self.id = id
        self.session = session
    }

    public var fields: [String: String] {
        ["ask": id, "session": session]
    }

    public init?(fields: [String: String]) {
        guard let id = fields["ask"], let session = fields["session"] else {
            return nil
        }

        self.init(id: id, session: session)
    }
}

/// SitRep to its helper. A request carries an id its answer gives back.
public enum ToHelper: Relayed {
    /// SitRep listens: said as it starts, and in answer to the helper's first `ready`.
    case ready
    case post(Notice)
    /// What macOS lets SitRep do, answered by `ToSitRep.status`.
    case status(id: String)
    /// macOS asked for leave, unless Lee answered already, then answered as `status` is.
    case ask(id: String)
    /// The front given back to the app Lee was in: the jump for a click the helper relayed was refused.
    case handBack
    /// The ask of the session waits on Lee no more: its banners still delivered go.
    case cleared(ask: String, session: String)

    public static let way = "to-helper"

    public var fields: [String: String] {
        switch self {
        case .ready: [kind: "ready"]
        case let .post(notice): notice.fields.merging([kind: "post"]) { _, kind in kind }
        case let .status(id): [kind: "status", "id": id]
        case let .ask(id): [kind: "ask", "id": id]
        case .handBack: [kind: "hand-back"]
        case let .cleared(ask, session): [kind: "cleared", "ask": ask, "session": session]
        }
    }

    public init?(fields: [String: String]) {
        switch (fields[kind], fields["id"]) {
        case ("ready", _): self = .ready
        case ("hand-back", _): self = .handBack
        case ("post", _):
            guard let notice = Notice(fields: fields) else {
                return nil
            }

            self = .post(notice)
        case let ("status", id?): self = .status(id: id)
        case let ("ask", id?): self = .ask(id: id)
        case ("cleared", _):
            guard let ask = fields["ask"], let session = fields["session"] else {
                return nil
            }

            self = .cleared(ask: ask, session: session)
        default: return nil
        }
    }
}

/// The helper to SitRep.
public enum ToSitRep: Relayed {
    /// The helper with this pid listens: said once it knows its SitRep, and in answer to SitRep's first `ready`. Its
    /// pid tells one helper from the next, as macOS may start one for a click before SitRep hears the last end.
    case ready(helper: Int32)
    /// A banner clicked, naming the session it jumps to.
    case clicked(work: String)
    /// What macOS lets SitRep do, for the request with this id.
    case status(NoticeLeave, id: String)

    public static let way = "to-sitrep"

    public var fields: [String: String] {
        switch self {
        case let .ready(helper): [kind: "ready", "helper": String(helper)]
        case let .clicked(work): [kind: "clicked", "work": work]
        case let .status(leave, id): [kind: "status", "leave": leave.word, "id": id]
        }
    }

    public init?(fields: [String: String]) {
        let helper = fields["helper"].flatMap(Int32.init)
        let leave = fields["leave"].flatMap(NoticeLeave.init(word:))

        switch (fields[kind], helper, fields["work"], leave, fields["id"]) {
        case let ("ready", helper?, _, _, _): self = .ready(helper: helper)
        case let ("clicked", _, work?, _, _): self = .clicked(work: work)
        case let ("status", _, _, leave?, id?): self = .status(leave, id: id)
        default: return nil
        }
    }
}

/// The key naming which message a letter is.
private let kind = "kind"
