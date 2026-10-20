import CoreGraphics

/// A session as the edge shows it: a row on the panel, a mark on the strip, and a mark's tab.
public struct Session: Equatable, Sendable {
    /// Where it stands.
    public enum Kind: Sendable {
        case needs, turn, working
    }

    public let id: String
    /// Its project's name, as Lee would say it.
    public var project: String
    /// The project's two letters, as its mark on the strip shows them.
    public var letters: String
    public var kind: Kind
    /// An ask no window holds: its row and its tab say so, and none of them takes a click.
    public var away: Bool
    public var title: String
    /// Set in code type after the title, as in an ask to allow a command.
    public var code: String?
    /// How many more questions it holds, as core words it: "+2".
    public var more: String?
    /// Its project and session.
    public var sub: String
    /// When it came to stand where it does, ms on the wall clock.
    public var since: Double

    public init(
        id: String, project: String, letters: String? = nil, kind: Kind, away: Bool = false, title: String,
        code: String? = nil, more: String? = nil, sub: String, since: Double
    ) {
        self.id = id
        self.project = project
        self.letters = letters ?? Self.letters(of: project)
        self.kind = kind
        self.away = away
        self.title = title
        self.code = code
        self.more = more
        self.sub = sub
        self.since = since
    }

    /// A project's letters as the prototypes have them, where none are given: its two capitals where it has two
    /// (SitRep SR, DocMan DM), else its first two (Switchboard Sw, agntc ag).
    static func letters(of project: String) -> String {
        let caps = project.filter { $0.isASCII && $0.isUppercase }
        return caps.count >= 2 ? String(caps.prefix(2)) : String(project.prefix(2))
    }

    /// A click on it jumps, unless no window holds it.
    public var jumps: Bool { !away }

    /// How long it has stood where it does at this time on the wall clock, as its row shows it.
    public func ageText(at now: Double) -> String { Self.ageText(now - since) }

    /// When on the wall clock its time may next read differently: at its next whole minute.
    public func ageChanges(after now: Double) -> Double {
        since + Self.minute * max(1, ((now - since) / Self.minute).rounded(.down) + 1)
    }

    private static let minute = 60_000.0

    /// An age in ms as a row shows it (the prototype's `age`): now, then whole minutes, hours or days.
    public static func ageText(_ age: Double) -> String {
        switch Age(age) {
        case .now: "now"
        case let .minutes(count): "\(count)m"
        case let .hours(count): "\(count)h"
        case let .days(count): "\(count)d"
        }
    }
}

/// An age as a row counts it: under a minute, now; then whole minutes, under an hour; whole hours, under a day; and
/// whole days.
public enum Age: Equatable, Sendable {
    case now
    case minutes(Int)
    case hours(Int)
    case days(Int)

    /// This age in ms.
    public init(_ age: Double) {
        let minutes = Int((age / 60_000).rounded(.down))
        let hours = minutes / 60

        self = minutes < 1 ? .now : minutes < 60 ? .minutes(minutes) : hours < 24 ? .hours(hours) : .days(hours / 24)
    }
}

/// One item in the panel's list, below its head: a session's row, or the hairline under what needs Lee.
public enum Item: Equatable, Sendable {
    case session(Session)
    case divider

    /// The panel's list of these sessions, in the order given, which is core's: the hairline under the needs you that
    /// lead it, when anything follows them.
    public static func list(_ sessions: [Session]) -> [Item] {
        let needs = sessions.prefix { $0.kind == .needs }.count
        var items = sessions.map(Item.session)
        if needs > 0, needs < items.count {
            items.insert(.divider, at: needs)
        }
        return items
    }

    /// The session it shows; nil for the divider.
    public var session: Session? {
        if case let .session(session) = self {
            return session
        }
        return nil
    }

    /// What it is, the same for as long as it shows: its session's id, or the one divider's.
    public var key: String { session?.id ?? "divider" }

    /// The gap below a row, inside its item.
    public static let rowGap = 4.0

    /// Its height, unfolded, as its rows are drawn: a row, 10 + 34 of text + 11, and the gap below it; the divider's
    /// 1 between 2 and 6.
    public var height: Double { session == nil ? 9 : 55 + Self.rowGap }
}

/// The panel's head: how many rows need Lee at the left, and how many sessions there are at the right, as core counts
/// them.
public struct Head: Equatable, Sendable {
    public let title: String
    public let count: String

    public init(title: String, count: String) {
        self.title = title
        self.count = count
    }

    public init(needYou: Int, sessions: Int) {
        self.init(
            title: needYou == 0 ? "All clear" : "\(needYou) need\(needYou == 1 ? "s" : "") you",
            count: "\(sessions) session\(sessions == 1 ? "" : "s")"
        )
    }
}

/// The panel's content, as the view lays it out: the head's height, and each item with its own. The scroll's padding
/// is the prototype's, above the head and below the last item.
public struct Content: Equatable, Sendable {
    /// An item and its height, which a fold shrinks; how opaque it is as it fades in or folds away; and whether it is
    /// folding away, when it takes no click.
    public struct Entry: Equatable, Sendable {
        public var item: Item
        public var height: Double
        public var alpha: Double
        public var isGoing: Bool

        public init(_ item: Item, height: Double, alpha: Double = 1, isGoing: Bool = false) {
            self.item = item
            self.height = height
            self.alpha = alpha
            self.isGoing = isGoing
        }

        /// Whether a click on it jumps: it is a session's row a window holds, and not folding away.
        public var jumps: Bool { !isGoing && item.session?.jumps == true }
    }

    public var headHeight: Double
    public var entries: [Entry]

    public init(headHeight: Double, entries: [Entry]) {
        self.headHeight = headHeight
        self.entries = entries
    }

    /// The panel's list, in the order each frame paints it.
    public var items: [Item] { entries.map(\.item) }

    static let paddingTop = 18.0, paddingBottom = 14.0, paddingSide = 14.0

    /// The panel's list laid out as its rows are drawn, unfolded, under the head's 16 line and the 10 below it.
    public init(laying items: [Item]) {
        self.init(headHeight: Self.headHeight, entries: items.map { Entry($0, height: $0.height) })
    }

    static let headHeight = 26.0

    /// The whole of it, padding and all, before the panel's height caps it: past that, the rows scroll.
    public var height: Double { Self.paddingTop + headHeight + entries.map(\.height).reduce(0, +) + Self.paddingBottom }

    /// How far down it is scrolled after a scroll of this many points down, in a panel showing this much of it: from
    /// its top to where its last row shows at the panel's foot.
    public func scrolled(_ offset: Double, by delta: Double, showing shown: Double) -> Double {
        clamp(offset + delta, 0, max(0, height - shown))
    }

    /// The head's box, in the content's own frame: inside the scroll's padding, the panel's depth less its sides.
    public var headFrame: CGRect {
        CGRect(x: Self.paddingSide, y: Self.paddingTop, width: Self.width, height: headHeight)
    }

    /// Each item's box, in the content's own frame, under the head and the items before it.
    public func itemFrame(_ index: Int) -> CGRect {
        let above = entries[..<index].map(\.height).reduce(0, +)
        return CGRect(x: Self.paddingSide, y: headFrame.maxY + above, width: Self.width, height: entries[index].height)
    }

    /// The item whose row holds a point in the content's own frame: never the divider, nor the gap below a row, nor a
    /// row folding away.
    public func row(at point: CGPoint) -> Int? {
        entries.indices.first { i in
            guard entries[i].item.session != nil, !entries[i].isGoing else {
                return false
            }

            var row = itemFrame(i)
            row.size.height -= Item.rowGap
            return row.contains(point)
        }
    }

    private static let width = Tuning.panelDepth - 2 * paddingSide
}
