extension WatchLine {
    /// A line's words, in parts: `lead`; `mono`, the subject set in mono; `subject`, one set plain; `more`, a
    /// question's `+2`; `until`, when the wake a line on its own work waits on is due.
    public struct Words: Encodable, Sendable, ExpressibleByStringInterpolation {
        public var lead: String
        @OrNull public var mono: String?
        @OrNull public var subject: String?
        @OrNull public var more: String?
        @OrNull public var until: Int?

        public init(lead: String, mono: String? = nil, subject: String? = nil, more: String? = nil, until: Int? = nil) {
            self.lead = lead
            self.mono = mono
            self.subject = subject
            self.more = more
            self.until = until
        }

        public init(stringLiteral lead: String) {
            self.init(lead: lead)
        }
    }

    /// What a row's line is.
    public enum Kind: String, Encodable, Sendable {
        case ask, permission, question, working, onItsWork, yourTurn

        /// The section core puts a row of it in.
        var section: Section {
            switch self {
            case .ask, .permission, .question: .needsYou
            case .yourTurn: .yourTurn
            case .working, .onItsWork: .working
            }
        }
    }

    public enum Section: String, Encodable, Sendable {
        case needsYou, yourTurn, working
    }

    /// A session's row: its lines, the newest first, in the section its newest's kind puts it in, named by its project
    /// and session, its second line theirs and its time its newest line's, unless given.
    public struct Row: Encodable, Sendable {
        /// One of a row's lines: an ask, a window's stop, or the session's turn.
        public struct Line: Encodable, Sendable {
            public var key: String
            public var `is`: Kind
            @OrNull public var ask: String?
            @OrNull public var writer: String?
            public var first: Words
            public var since: Int

            public init(
                _ key: String, _ kind: Kind, ask: String? = nil, writer: String? = nil, first: Words,
                since: Int = 1_792_445_000_000
            ) {
                self.key = key
                self.is = kind
                self.ask = ask
                self.writer = writer
                self.first = first
                self.since = since
            }
        }

        public var session: String
        public var section: Section
        public var isAway: Bool
        /// Its project's key.
        public var project: String
        public var name: String
        public var projectName: String
        public var letters: String
        public var lines: [Line]
        public var second: String
        public var since: Int

        /// Its project's key is its name in lower case, and its letters core's for that name, unless given.
        public init(
            session: String = "sr-nw0001", section: Section? = nil, isAway: Bool = false, project: String? = nil,
            name: String = "Ledger export", projectName: String = "Northwind", letters: String? = nil,
            second: String? = nil, since: Int? = nil, lines: [Line]
        ) {
            self.session = session
            self.section = section ?? lines[0].is.section
            self.isAway = isAway
            self.project = project ?? projectName.lowercased()
            self.name = name
            self.projectName = projectName
            self.letters = letters ?? WatchLine.letters(of: projectName)
            self.lines = lines
            self.second = second ?? "\(projectName) · \(name)"
            self.since = since ?? lines[0].since
        }
    }

    /// What a Snoozed row's line is: an ask snoozed, or the session's turn.
    public enum SnoozedKind: String, Encodable, Sendable {
        case ask, yourTurn
    }

    /// A session's row in Snoozed, named as its row is, waking when its soonest line does, unless given.
    public struct SnoozedRow: Encodable, Sendable {
        /// One of its lines, under the key it has in Needs you or Your turn, waking at `wakesAt`, none for a turn
        /// snoozed until it moves.
        public struct Line: Encodable, Sendable {
            public var key: String
            public var `is`: SnoozedKind
            @OrNull public var ask: String?
            public var first: Words
            public var since: Int
            @OrNull public var wakesAt: Int?

            public init(
                _ key: String, _ kind: SnoozedKind = .ask, ask: String? = nil, first: Words,
                since: Int = 1_792_445_000_000, wakesAt: Int?
            ) {
                self.key = key
                self.is = kind
                self.ask = ask
                self.first = first
                self.since = since
                self.wakesAt = wakesAt
            }
        }

        public var session: String
        public var isAway: Bool
        public var project: String
        public var name: String
        public var projectName: String
        public var letters: String
        public var lines: [Line]
        public var second: String
        @OrNull public var wakesAt: Int?

        public init(
            session: String = "sr-nw0001", isAway: Bool = false, project: String? = nil, name: String = "Ledger export",
            projectName: String = "Northwind", letters: String? = nil, second: String? = nil, lines: [Line]
        ) {
            self.session = session
            self.isAway = isAway
            self.project = project ?? projectName.lowercased()
            self.name = name
            self.projectName = projectName
            self.letters = letters ?? WatchLine.letters(of: projectName)
            self.lines = lines
            self.second = second ?? "\(projectName) · \(name)"
            self.wakesAt = lines.compactMap(\.wakesAt).min()
        }
    }

    /// A project's two letters, as core's `lettersOf` gives them: its capitals where it has two, else its first two
    /// letters or digits.
    static func letters(of name: String) -> String {
        let capitals = name.filter(\.isUppercase)
        let letters = capitals.count >= 2 ? capitals : name.filter { $0.isLetter || $0.isNumber }

        return String(letters.prefix(2))
    }
}
