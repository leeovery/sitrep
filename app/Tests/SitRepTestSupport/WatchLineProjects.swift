extension WatchLine {
    /// A project with a current session. What core derives is derived as it prints, from the project as it then
    /// stands, unless given: its key from its name, as core's `slug`; its counts, its sessions' held open, waiting,
    /// snoozed and parked; and when it was updated, as its latest session was.
    public struct Project: Encodable, Sendable {
        public var key: String?
        public var name: String
        @OrNull public var directory: String?
        public var open: Int?
        public var waiting: Int?
        public var snoozed: Int?
        public var parked: Int?
        public var updatedAt: Int?
        public var sessions: [Session]

        public init(
            key: String? = nil, name: String = "Northwind", directory: String? = nil, open: Int? = nil,
            waiting: Int? = nil, snoozed: Int? = nil, parked: Int? = nil, updatedAt: Int? = nil,
            sessions: [Session] = []
        ) {
            self.key = key
            self.name = name
            self.directory = directory
            self.open = open
            self.waiting = waiting
            self.snoozed = snoozed
            self.parked = parked
            self.updatedAt = updatedAt
            self.sessions = sessions
        }

        public func encode(to encoder: any Encoder) throws {
            var project = encoder.container(keyedBy: Key.self)

            try project.encode(key ?? WatchLine.key(of: name), forKey: .key)
            try project.encode(name, forKey: .name)
            try project.encode(_directory, forKey: .directory)
            try project.encode(open ?? sessions.filter(\.isOpen).count, forKey: .open)
            try project.encode(waiting ?? sessions.map(\.waitingCount).reduce(0, +), forKey: .waiting)
            try project.encode(snoozed ?? sessions.map(\.snoozedCount).reduce(0, +), forKey: .snoozed)
            try project.encode(parked ?? sessions.map(\.parkedCount).reduce(0, +), forKey: .parked)
            try project.encode(updatedAt ?? sessions.map(\.updatedAt).max() ?? 1_792_440_000_000, forKey: .updatedAt)
            try project.encode(sessions, forKey: .sessions)
        }

        private enum Key: String, CodingKey {
            case key, name, directory, open, waiting, snoozed, parked, updatedAt, sessions
        }
    }

    /// Where a session stands.
    public enum State: String, Encodable, Sendable {
        case needsYou, working, onItsWork, yourTurn, away
    }

    /// A session as `list --json` gives it, with where it stands, what it is doing, its open asks, what it parked and,
    /// away, the window it was last in. Its counts are derived as it prints, unless given, as core counts them: its
    /// asks waiting on Lee, those snoozed aside; its asks snoozed; and what it parked.
    public struct Session: Encodable, Sendable {
        public var id: String
        public var name: String
        public var summary: String
        public var now: [String]
        @OrNull public var next: String?
        public var isOpen: Bool
        public var waiting: Int?
        public var snoozed: Int?
        public var parked: Int?
        public var created: Int
        public var updatedAt: Int
        public var state: State
        public var since: Int
        public var doing: Doing
        public var asks: [Ask]
        public var parkedItems: [Parked]
        @OrNull public var lastWindow: LastWindow?

        public init(
            id: String = "sr-nw0001", name: String = "Ledger export", summary: String = "", now: [String] = [],
            next: String? = nil, isOpen: Bool = true, waiting: Int? = nil, snoozed: Int? = nil, parked: Int? = nil,
            created: Int = 1_792_440_000_000, updatedAt: Int = 1_792_440_000_000, state: State = .working,
            since: Int = 1_792_440_000_000, doing: Doing = Doing(.working, line: "Working"), asks: [Ask] = [],
            parkedItems: [Parked] = [], lastWindow: LastWindow? = nil
        ) {
            self.id = id
            self.name = name
            self.summary = summary
            self.now = now
            self.next = next
            self.isOpen = isOpen
            self.waiting = waiting
            self.snoozed = snoozed
            self.parked = parked
            self.created = created
            self.updatedAt = updatedAt
            self.state = state
            self.since = since
            self.doing = doing
            self.asks = asks
            self.parkedItems = parkedItems
            self.lastWindow = lastWindow
        }

        /// Core's `waiting`: its asks waiting on Lee, those snoozed aside.
        var waitingCount: Int {
            waiting ?? asks.filter { $0.waitsOnLee && !$0.isSnoozed }.count
        }

        /// Core's `snoozed`: its asks snoozed.
        var snoozedCount: Int {
            snoozed ?? asks.filter(\.isSnoozed).count
        }

        var parkedCount: Int {
            parked ?? parkedItems.count
        }

        public func encode(to encoder: any Encoder) throws {
            var session = encoder.container(keyedBy: Key.self)

            try session.encode(id, forKey: .id)
            try session.encode(name, forKey: .name)
            try session.encode(summary, forKey: .summary)
            try session.encode(now, forKey: .now)
            try session.encode(_next, forKey: .next)
            try session.encode(isOpen, forKey: .isOpen)
            try session.encode(waitingCount, forKey: .waiting)
            try session.encode(snoozedCount, forKey: .snoozed)
            try session.encode(parkedCount, forKey: .parked)
            try session.encode(created, forKey: .created)
            try session.encode(updatedAt, forKey: .updatedAt)
            try session.encode(state, forKey: .state)
            try session.encode(since, forKey: .since)
            try session.encode(doing, forKey: .doing)
            try session.encode(asks, forKey: .asks)
            try session.encode(parkedItems, forKey: .parkedItems)
            try session.encode(_lastWindow, forKey: .lastWindow)
        }

        private enum Key: String, CodingKey {
            case id, name, summary, now, next, isOpen, waiting, snoozed, parked, created, updatedAt, state, since, doing
            case asks, parkedItems, lastWindow
        }
    }

    /// What a session is doing, as the line under its name says it.
    public struct Doing: Encodable, Sendable {
        public enum Kind: String, Encodable, Sendable {
            case working, permission, question, onItsWork, yourTurn, away
        }

        public var `is`: Kind
        public var line: Words
        public var since: Int

        public init(_ kind: Kind, line: Words, since: Int = 1_792_440_000_000) {
            self.is = kind
            self.line = line
            self.since = since
        }
    }

    /// An open ask, as `board --json` lists it: its yes button's words only where it wants a yes, and its snooze as
    /// `snoozedUntil`, none for one until it moves, which `untilItMoves` says.
    public struct Ask: Encodable, Sendable {
        public enum Wants: String, Encodable, Sendable {
            case yes, choice, words
        }

        public enum State: String, Encodable, Sendable {
            case waiting, replied, closed, ignored
        }

        /// Lee's snooze of it: until a time, or until it moves.
        public enum Snooze: Sendable {
            case until(Int)
            case untilItMoves
        }

        /// Where Lee's reply to it stands.
        public struct Reply: Encodable, Sendable {
            public enum Kind: String, Encodable, Sendable {
                case onItsWay, delivered, notDelivered
            }

            public var `is`: Kind
            public var isAnswer: Bool
            @OrNull public var words: String?
            public var since: Int

            public init(_ kind: Kind, isAnswer: Bool = true, words: String? = nil, since: Int = 1_792_440_000_000) {
                self.is = kind
                self.isAnswer = isAnswer
                self.words = words
                self.since = since
            }
        }

        public var id: String
        public var wants: Wants
        public var yes: String?
        public var title: String
        public var `where`: String?
        public var options: [String]
        public var recommended: String?
        public var needs: String?
        public var ref: String?
        public var state: State
        public var at: Int
        public var reply: Reply?
        public var snooze: Snooze?

        public init(
            id: String = "k1", wants: Wants = .yes, yes: String? = "Approve", title: String = "Pick the export format",
            where: String? = nil, options: [String] = [], recommended: String? = nil, needs: String? = nil,
            ref: String? = nil, state: State = .waiting, at: Int = 1_792_440_000_000, reply: Reply? = nil,
            snooze: Snooze? = nil
        ) {
            self.id = id
            self.wants = wants
            self.yes = yes
            self.title = title
            self.where = `where`
            self.options = options
            self.recommended = recommended
            self.needs = needs
            self.ref = ref
            self.state = state
            self.at = at
            self.reply = reply
            self.snooze = snooze
        }

        /// Core's `waitsOnLee`: waiting, with no reply of Lee's on its way.
        var waitsOnLee: Bool {
            state == .waiting && reply?.is != .onItsWay
        }

        /// Core's `isSnoozed`: waiting on Lee, and snoozed.
        var isSnoozed: Bool {
            waitsOnLee && snooze != nil
        }

        public func encode(to encoder: any Encoder) throws {
            var ask = encoder.container(keyedBy: Key.self)
            let wakes: Int? = if case let .until(time) = snooze, isSnoozed { time } else { nil }
            let untilItMoves = if case .untilItMoves = snooze, isSnoozed { true } else { false }

            try ask.encode(id, forKey: .id)
            try ask.encode(wants, forKey: .wants)
            try ask.encode(wants == .yes ? yes : nil, forKey: .yes)
            try ask.encode(title, forKey: .title)
            try ask.encode(self.where, forKey: .where)
            try ask.encode(options, forKey: .options)
            try ask.encode(recommended, forKey: .recommended)
            try ask.encode(needs, forKey: .needs)
            try ask.encode(ref, forKey: .ref)
            try ask.encode(state, forKey: .state)
            try ask.encode(at, forKey: .at)
            try ask.encode(reply, forKey: .reply)
            try ask.encode(wakes, forKey: .snoozedUntil)
            try ask.encode(untilItMoves, forKey: .untilItMoves)
        }

        private enum Key: String, CodingKey {
            case id, wants, yes, title, `where`, options, recommended, needs, ref, state, at, reply, snoozedUntil
            case untilItMoves
        }
    }

    /// What a session parked.
    public struct Parked: Encodable, Sendable {
        public var id: String
        public var title: String
        @OrNull public var `where`: String?
        @OrNull public var ref: String?
        public var at: Int

        public init(
            id: String = "p1", title: String = "Tidy the export names", where: String? = nil, ref: String? = nil,
            at: Int = 1_792_440_000_000
        ) {
            self.id = id
            self.title = title
            self.where = `where`
            self.ref = ref
            self.at = at
        }
    }

    /// The window an away session was last in: its writer, where it was, whether its device is still its
    /// conversation's, and the folder its Claude ran in.
    public struct LastWindow: Encodable, Sendable {
        public var writer: String
        @OrNull public var `where`: Where?
        public var ownsDevice: Bool
        @OrNull public var directory: String?

        public init(writer: String, where: Where? = nil, ownsDevice: Bool = true, directory: String? = nil) {
            self.writer = writer
            self.where = `where`
            self.ownsDevice = ownsDevice
            self.directory = directory
        }
    }
}
