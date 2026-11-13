import CoreGraphics

/// A session as the edge shows it: a row on the panel, a mark on the strip, and a mark's tab. One needing Lee has a
/// line for each ask and stop waiting on Lee, the newest first; its row in Snoozed, on the card alone, a line for each
/// ask asleep, or its turn's alone; any other has its one line.
public struct Session: Equatable, Sendable {
    /// Where it stands: its turn over but on its own work, which will wake it, among them; or, a row in Snoozed, its
    /// asks asleep, or its turn Lee snoozed.
    public enum Kind: Sendable {
        case needs, turn, working, onItsWork, snoozed, snoozedTurn
    }

    /// One of its lines: its words, and its time.
    public struct Line: Equatable, Sendable {
        /// The ask it is, by its id; nil for a window's stop or the session's turn.
        public var ask: String?
        public var title: String
        /// Set in code type after the title, as in an ask to allow a command.
        public var code: String?
        /// Set plain after the title, where what it waits on is no command: "3 agents".
        public var subject: String?
        /// When the wake it waits on is due, ms on the wall clock: its subject counts down to it, "in 12m".
        public var until: Double?
        /// How many more questions it holds, as core words it: "+2".
        public var more: String?
        /// When it began, ms on the wall clock.
        public var since: Double

        public init(
            ask: String? = nil, title: String, code: String? = nil, subject: String? = nil, until: Double? = nil,
            more: String? = nil, since: Double
        ) {
            self.ask = ask
            self.title = title
            self.code = code
            self.subject = subject
            self.until = until
            self.more = more
            self.since = since
        }

        /// How long it has stood at this time on the wall clock, as its row shows it.
        public func ageText(at now: Double) -> String { Session.ageText(now - since) }

        /// When on the wall clock its time may next read differently: at its next whole minute.
        public func ageChanges(after now: Double) -> Double {
            since + Session.minute * max(1, ((now - since) / Session.minute).rounded(.down) + 1)
        }

        /// What it waits on, set plain after the title at this time on the wall clock: a wake's countdown, else its
        /// subject.
        public func subject(at now: Double) -> String? {
            until.map { Session.untilText($0 - now) } ?? subject
        }

        /// When on the wall clock its words may next read differently: its time, or a wake's countdown.
        public func changes(after now: Double) -> Double {
            min(ageChanges(after: now), countdownChanges(after: now) ?? .infinity)
        }

        /// When on the wall clock a wake's countdown next reads differently: as it passes a whole minute before the
        /// wake, and as the wake comes due; nil with no wake, or one due, which reads "now" for good.
        public func countdownChanges(after now: Double) -> Double? {
            guard let until, until > now else {
                return nil
            }

            return until - Session.minute * (((until - now) / Session.minute).rounded(.up) - 1)
        }

        /// The readings of a wake's countdown a row leaves room for from this time on: its reading now, and the widest
        /// of each smaller unit still to come, "in 23h" and "in 59m", as wide as any of its unit with the figures
        /// tabular, as the views set them; none with no wake.
        public func countdownRoom(after now: Double) -> [String] {
            guard let until else {
                return []
            }

            let left = until - now
            let minutes = (left / Session.minute).rounded(.up)
            let later = minutes >= 24 * 60 ? ["in 23h", "in 59m"] : minutes >= 60 ? ["in 59m"] : []

            return [Session.untilText(left)] + later
        }
    }

    public let id: String
    /// Its project's name, as Lee would say it.
    public var project: String
    /// Its name, which its row shows as its title while it needs Lee.
    public var name: String
    /// The project's two letters, as its mark on the strip shows them.
    public var letters: String
    public var kind: Kind
    /// Not here: no window holding it, or none this Mac shows (DESIGN, stage 8). Its row and its tab are drawn away,
    /// and a click on them carries it on.
    public var away: Bool
    /// Needing Lee, the newest first, as core has them; in Snoozed, the soonest to wake first; never none.
    public var lines: [Line]
    /// What its row says under its title.
    public var sub: String
    /// A row in Snoozed: when its soonest line wakes, ms on the wall clock, which the row shows in its time's place;
    /// nil for a turn snoozed until it moves.
    public var wakesAt: Double?

    public init(
        id: String, project: String, name: String = "", letters: String? = nil, kind: Kind, away: Bool = false,
        lines: [Line], sub: String, wakesAt: Double? = nil
    ) {
        precondition(!lines.isEmpty, "a session's row has a line")
        self.id = id
        self.project = project
        self.name = name
        self.letters = letters ?? Self.letters(of: project)
        self.kind = kind
        self.away = away
        self.lines = lines
        self.sub = sub
        self.wakesAt = wakesAt
    }

    /// A session of one line.
    public init(
        id: String, project: String, name: String = "", letters: String? = nil, kind: Kind, away: Bool = false,
        ask: String? = nil, title: String, code: String? = nil, subject: String? = nil, until: Double? = nil,
        more: String? = nil, sub: String, since: Double
    ) {
        let line = Line(ask: ask, title: title, code: code, subject: subject, until: until, more: more, since: since)

        self.init(id: id, project: project, name: name, letters: letters, kind: kind, away: away, lines: [line], sub: sub)
    }

    /// What its row says, on every surface, on one line with its time: needing Lee, or in Snoozed, its name, and "3"
    /// for three lines waiting, none for one, its time its first line's, needing Lee the newest; else its one line. A
    /// row needing Lee shows its session, not its asks, so a question's own "+2" shows nowhere on it.
    public var headline: Line {
        guard needsLee || isSnoozed else {
            return lines[0]
        }

        return Line(title: name, more: Self.more(over: lines.count), since: lines[0].since)
    }

    /// What follows a session's name on a row needing Lee of this many lines: their plain number, "3" for three, since
    /// the name leads and no line does; none for one, the row itself saying something waits.
    public static func more(over lines: Int) -> String? {
        lines > 1 ? "\(lines)" : nil
    }

    public var title: String { headline.title }
    public var code: String? { headline.code }
    public var subject: String? { headline.subject }
    public var until: Double? { headline.until }
    public var more: String? { headline.more }

    /// The time its row counts from: needing Lee, its newest line's; else its one line's.
    public var since: Double { headline.since }

    /// A project's letters as the prototypes have them, where none are given: its two capitals where it has two
    /// (SitRep SR, DocMan DM), else its first two (Switchboard Sw, agntc ag).
    static func letters(of project: String) -> String {
        let caps = project.filter { $0.isASCII && $0.isUppercase }
        return caps.count >= 2 ? String(caps.prefix(2)) : String(project.prefix(2))
    }

    /// Whether it is among needs you.
    public var needsLee: Bool { kind == .needs }

    /// Whether it is a row in Snoozed, its asks asleep or its turn.
    public var isSnoozed: Bool { kind == .snoozed || kind == .snoozedTurn }

    /// Whether it is its session's turn, waiting on Lee's message or snoozed: what its row's Snooze puts off, by the
    /// turn's end, its time.
    public var isTurn: Bool { kind == .turn || kind == .snoozedTurn }

    /// The asks its lines show, by their ids, a window's stops aside: what its row snoozes, or wakes.
    public var asks: [String] { lines.compactMap(\.ask) }

    /// How long its row has stood at this time on the wall clock, from its headline's time.
    public func ageText(at now: Double) -> String { headline.ageText(at: now) }

    /// What its row waits on, set plain after its title at this time on the wall clock.
    public func subject(at now: Double) -> String? { headline.subject(at: now) }

    /// When on the wall clock its row's words may next read differently: its time, or a wake's countdown.
    public func changes(after now: Double) -> Double { headline.changes(after: now) }

    /// When on the wall clock its wake's countdown next reads differently (`Line.countdownChanges`).
    public func countdownChanges(after now: Double) -> Double? { headline.countdownChanges(after: now) }

    /// The readings of its wake's countdown a row leaves room for (`Line.countdownRoom`).
    public func countdownRoom(after now: Double) -> [String] { headline.countdownRoom(after: now) }

    fileprivate static let minute = 60_000.0

    /// The time until a wake in ms as its countdown reads (`Age`, up to the whole minute): "in 12m", "in 2h", "in
    /// 3d"; "now" once it is due.
    public static func untilText(_ left: Double) -> String {
        left <= 0 ? "now" : "in \(ageText((left / minute).rounded(.up) * minute))"
    }

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

/// One item in the panel's list, below any head: a session's row, drawn whole, as the menu's list and the prototypes'
/// have it, or on the card on one line; a section's eyebrow; or the menu's hairline after what waits on Lee.
public enum Item: Equatable, Sendable {
    case session(Session)
    /// A row on the card, on one line, whatever its section (board J).
    case line(Session)
    case eyebrow(Eyebrow)
    case divider

    /// The panel's list of these sessions, in the order given, which is core's: the hairline under what waits on Lee
    /// that leads it, needs you and your turn, when anything follows them. The menu's; the card's is `card`.
    public static func list(_ sessions: [Session]) -> [Item] {
        let waiting = sessions.prefix(while: \.section.waitsOnLee).count
        var items = sessions.map(Item.session)
        if waiting > 0, waiting < items.count {
            items.insert(.divider, at: waiting)
        }
        return items
    }

    /// The session its row shows; nil for any other item.
    public var session: Session? {
        switch self {
        case let .session(session), let .line(session): session
        case .eyebrow, .divider: nil
        }
    }

    /// What it is, the same for as long as it shows: a row by its session, marked by its section but for Working's, so
    /// a row changing section folds away from one place and unfolds in the other, as two rows, and a session's row in
    /// Snoozed is another than its row beside it, and its turn's row there another than its asks'; an eyebrow by its
    /// section; the divider by itself.
    public var key: String {
        switch self {
        case let .session(session), let .line(session): Self.key(of: session)
        case let .eyebrow(eyebrow): "eyebrow:\(eyebrow.section.rawValue)"
        case .divider: "divider"
        }
    }

    static func key(of session: Session) -> String {
        switch session.section {
        case .needsYou: "needs:\(session.id)"
        case .yourTurn: "turn:\(session.id)"
        case .working: session.id
        case .snoozed: session.isTurn ? "snoozedTurn:\(session.id)" : "snoozed:\(session.id)"
        }
    }

    /// The gap below a row drawn whole, inside its item.
    public static let rowGap = 4.0

    /// A row drawn whole, less the gap below it: 7, its two lines' 34, and 8.
    public static let rowHeight = 49.0

    /// Board D's: a row on one line, with no gap, so the lifts of two meet; and an eyebrow, under the room over it.
    public static let lineHeight = 30.0, eyebrowHeight = 28.0

    /// Its height, unfolded, as it is drawn: a row whole, however many lines it holds, and the gap below it; a row on
    /// one line's 30; an eyebrow's 28 under its room; the divider's 1 between 2 and 6.
    public var height: Double {
        switch self {
        case .session: Self.rowHeight + Self.rowGap
        case .line: Self.lineHeight
        case let .eyebrow(eyebrow): eyebrow.above + Self.eyebrowHeight
        case .divider: 9
        }
    }

    /// The room in its item over what it draws, and under it: what takes no click.
    public var margins: (above: Double, below: Double) {
        switch self {
        case .session: (0, Self.rowGap)
        case .line, .divider: (0, 0)
        case let .eyebrow(eyebrow): (eyebrow.above, 0)
        }
    }

    /// What it draws, in its item, which is this wide: its height less its margins.
    public func box(width: Double) -> CGRect {
        CGRect(x: 0, y: margins.above, width: width, height: height - margins.above - margins.below)
    }
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

/// The panel's content, as the view lays it out: the head's height, none where it has none, and each item with its
/// own. The scroll's padding is the prototype's, above the head and below the last item.
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

        /// Whether a click on it jumps: it is a session's row, and not folding away.
        public var jumps: Bool { !isGoing && item.session != nil }
    }

    /// The head's line and the room under it; 0 with no head, as on the card with its sections.
    public var headHeight: Double
    public var entries: [Entry]

    public init(headHeight: Double, entries: [Entry]) {
        self.headHeight = headHeight
        self.entries = entries
    }

    /// The panel's list, in the order each frame paints it.
    public var items: [Item] { entries.map(\.item) }

    static let paddingTop = 18.0, paddingBottom = 14.0, paddingSide = 14.0
    /// With no head, board D's padding over the first eyebrow, whose 4 and 28 bring the first row to 44, where it
    /// stood under the head.
    static let bareTop = 12.0

    /// The panel's list laid out as its rows are drawn, unfolded, under the head's 16 line and the 10 below it, or
    /// with no head.
    public init(laying items: [Item], headed: Bool = true) {
        self.init(headHeight: headed ? Self.headHeight : 0, entries: items.map { Entry($0, height: $0.height) })
    }

    public static let headHeight = 26.0

    /// Where the first item sits: under the head, inside the scroll's padding, or with none, board D's 12 down.
    public var top: Double { headHeight > 0 ? Self.paddingTop + headHeight : Self.bareTop }

    /// The whole of it, padding and all, before the panel's height caps it: past that, the rows scroll.
    public var height: Double { top + entries.map(\.height).reduce(0, +) + Self.paddingBottom }

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
        return CGRect(x: Self.paddingSide, y: top + above, width: Self.width, height: entries[index].height)
    }

    /// The item a click at a point in the content's own frame acts on, where it is drawn: a row or an eyebrow; never
    /// the divider, nor the room round an item, nor an item folding away.
    public func item(at point: CGPoint) -> Int? {
        entries.indices.first { i in
            let item = entries[i].item

            guard item != .divider, !entries[i].isGoing else {
                return false
            }

            let frame = itemFrame(i), margins = item.margins
            let drawn = CGRect(
                x: frame.minX, y: frame.minY + margins.above, width: frame.width,
                height: max(0, frame.height - margins.above - margins.below)
            )
            return drawn.contains(point)
        }
    }

    private static let width = Tuning.panelDepth - 2 * paddingSide
}
