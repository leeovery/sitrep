extension WatchLine {
    /// A project with a current session, counting its sessions' open ones, what waits, is snoozed and is parked, and
    /// updated as its latest session was, unless given.
    public struct Project: Encodable, Sendable {
        public var key: String
        public var name: String
        @OrNull public var directory: String?
        public var open: Int
        public var waiting: Int
        public var snoozed: Int
        public var parked: Int
        public var updatedAt: Int
        public var sessions: [Session]

        /// Its key is its name in lower case, unless given.
        public init(
            key: String? = nil, name: String = "Northwind", directory: String? = nil, open: Int? = nil, waiting: Int? = nil,
            snoozed: Int? = nil, parked: Int? = nil, updatedAt: Int? = nil, sessions: [Session] = []
        ) {
            self.key = key ?? name.lowercased()
            self.name = name
            self.directory = directory
            self.open = open ?? sessions.filter(\.isOpen).count
            self.waiting = waiting ?? sessions.map(\.waiting).reduce(0, +)
            self.snoozed = snoozed ?? sessions.map(\.snoozed).reduce(0, +)
            self.parked = parked ?? sessions.map(\.parked).reduce(0, +)
            self.updatedAt = updatedAt ?? sessions.map(\.updatedAt).max() ?? 1_792_440_000_000
            self.sessions = sessions
        }
    }

    /// Where a session stands.
    public enum State: String, Encodable, Sendable {
        case needsYou, working, onItsWork, yourTurn, away
    }

    /// A session as `list --json` gives it, with where it stands, what it is doing, its open asks, what it parked and,
    /// away, the window it was last in.
    public struct Session: Encodable, Sendable {
        public var id: String
        public var name: String
        public var summary: String
        public var now: [String]
        @OrNull public var next: String?
        public var isOpen: Bool
        public var waiting: Int
        public var snoozed: Int
        public var parked: Int
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
            next: String? = nil, isOpen: Bool = true, waiting: Int = 0, snoozed: Int = 0, parked: Int = 0,
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

    /// An open ask, as `board --json` lists it: its yes button's words only where it wants a yes.
    public struct Ask: Encodable, Sendable {
        public enum Wants: String, Encodable, Sendable {
            case yes, choice, words
        }

        public enum State: String, Encodable, Sendable {
            case waiting, replied, closed, ignored
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
        @OrNull public var yes: String?
        public var title: String
        @OrNull public var `where`: String?
        public var options: [String]
        @OrNull public var recommended: String?
        @OrNull public var needs: String?
        @OrNull public var ref: String?
        public var state: State
        public var at: Int
        @OrNull public var reply: Reply?
        /// When its snooze wakes; none while it is not snoozed, and none for one snoozed until it moves.
        @OrNull public var snoozedUntil: Int?
        public var untilItMoves: Bool

        public init(
            id: String = "k1", wants: Wants = .yes, yes: String? = "Approve", title: String = "Pick the export format",
            where: String? = nil, options: [String] = [], recommended: String? = nil, needs: String? = nil,
            ref: String? = nil, state: State = .waiting, at: Int = 1_792_440_000_000, reply: Reply? = nil,
            snoozedUntil: Int? = nil, untilItMoves: Bool = false
        ) {
            self.id = id
            self.wants = wants
            self.yes = wants == .yes ? yes : nil
            self.title = title
            self.where = `where`
            self.options = options
            self.recommended = recommended
            self.needs = needs
            self.ref = ref
            self.state = state
            self.at = at
            self.reply = reply
            self.snoozedUntil = snoozedUntil
            self.untilItMoves = untilItMoves
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
