import Foundation

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

    /// The line core's rows print where no window holds the session (`AWAY_LINE`).
    public static let awayLine = "No window holds it. Carry it on in Claude."

    /// A session's row: its lines, printed newest first as core orders them, whatever order they are given in. What
    /// core derives is derived as it prints, from the row as it then stands, unless given: its section, its newest
    /// line's kind's; its time, its newest line's; its project's key, from the project's name; its second line, the
    /// project and the session, or, away, that no window holds it.
    public struct Row: Encodable, Sendable, Naming {
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

            /// Core's `byRecency`: the newest first, then by key.
            static func byRecency(_ a: Self, _ b: Self) -> Bool {
                a.since != b.since ? a.since > b.since : a.key.utf16.lexicographicallyPrecedes(b.key.utf16)
            }
        }

        public var session: String
        public var isAway: Bool
        public var project: String?
        public var name: String
        public var projectName: String
        public var second: String?
        public var section: Section?
        public var since: Int?
        public var lines: [Line]

        public init(
            session: String = "sr-nw0001", isAway: Bool = false, project: String? = nil, name: String = "Ledger export",
            projectName: String = "Northwind", second: String? = nil, section: Section? = nil, since: Int? = nil,
            lines: [Line]
        ) {
            self.session = session
            self.isAway = isAway
            self.project = project
            self.name = name
            self.projectName = projectName
            self.second = second
            self.section = section
            self.since = since
            self.lines = lines
        }

        /// Its lines as core orders them, the newest first.
        var newestFirst: [Line] {
            precondition(!lines.isEmpty, "A row has a line: core prints no row for a session with none.")
            return lines.sorted(by: Line.byRecency)
        }

        /// The section it prints in.
        var printedSection: Section {
            section ?? newestFirst[0].is.section
        }

        public func encode(to encoder: any Encoder) throws {
            let lines = newestFirst
            var row = encoder.container(keyedBy: RowKey.self)

            try encodeNaming(into: &row)
            try row.encode(printedSection, forKey: .section)
            try row.encode(lines, forKey: .lines)
            try row.encode(since ?? lines[0].since, forKey: .since)
        }
    }

    /// What a Snoozed row's line is: an ask snoozed, or the session's turn.
    public enum SnoozedKind: String, Encodable, Sendable {
        case ask, yourTurn
    }

    /// A session's row in Snoozed, named as its row is: its lines, printed the soonest to wake first, those snoozed
    /// until they move last, then the oldest, as core orders them; waking when its soonest line does.
    public struct SnoozedRow: Encodable, Sendable, Naming {
        /// One of its lines, under the key it has in Needs you or Your turn, waking at `wakesAt`, none for one snoozed
        /// until it moves.
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

            /// Core's `bySleep`: the soonest to wake first, those until they move last, then the oldest, then by key.
            static func bySleep(_ a: Self, _ b: Self) -> Bool {
                let wakes = (a.wakesAt ?? .max, b.wakesAt ?? .max)

                if wakes.0 != wakes.1 {
                    return wakes.0 < wakes.1
                }
                return a.since != b.since ? a.since < b.since : a.key.utf16.lexicographicallyPrecedes(b.key.utf16)
            }
        }

        public var session: String
        public var isAway: Bool
        public var project: String?
        public var name: String
        public var projectName: String
        public var second: String?
        public var lines: [Line]

        public init(
            session: String = "sr-nw0001", isAway: Bool = false, project: String? = nil, name: String = "Ledger export",
            projectName: String = "Northwind", second: String? = nil, lines: [Line]
        ) {
            self.session = session
            self.isAway = isAway
            self.project = project
            self.name = name
            self.projectName = projectName
            self.second = second
            self.lines = lines
        }

        public func encode(to encoder: any Encoder) throws {
            precondition(!lines.isEmpty, "A Snoozed row has a line: core prints none with nothing put off.")

            let lines = self.lines.sorted(by: Line.bySleep)
            var row = encoder.container(keyedBy: RowKey.self)

            try encodeNaming(into: &row)
            try row.encode(lines, forKey: .lines)
            try row.encode(lines[0].wakesAt, forKey: .wakesAt)
        }
    }

    /// A project's key, as core's `slug` makes one of its name: decomposed, its accents dropped, in lower case, each
    /// run of anything but `a-z` and `0-9` a dash, cut to 32, no dash at either end; `project` where nothing is left.
    static func key(of name: String) -> String {
        let bare = name.decomposedStringWithCompatibilityMapping.unicodeScalars.filter { !isMark($0) }
        let lower = String(String.UnicodeScalarView(bare)).lowercased()
        let dashed = lower.unicodeScalars.reduce(into: "") { slug, scalar in
            if ("a" ... "z").contains(scalar) || ("0" ... "9").contains(scalar) {
                slug.unicodeScalars.append(scalar)
            } else if !slug.hasSuffix("-") {
                slug += "-"
            }
        }
        let cut = String(dashed.prefix(32)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return cut.isEmpty ? "project" : cut
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }
}

/// The keys of a row and a Snoozed row, in one set, as both name their session alike.
enum RowKey: String, CodingKey {
    case session, section, isAway, project, name, projectName, lines, second, since, wakesAt
}

/// What names a row, in Needs you or Snoozed, as core's `namedRow` gives it: its project's key from the project's
/// name, and its second line the project and the session, or, away, that no window holds it, unless given.
protocol Naming {
    var session: String { get }
    var isAway: Bool { get }
    var project: String? { get }
    var name: String { get }
    var projectName: String { get }
    var second: String? { get }
}

extension Naming {
    func encodeNaming(into row: inout KeyedEncodingContainer<RowKey>) throws {
        try row.encode(session, forKey: .session)
        try row.encode(isAway, forKey: .isAway)
        try row.encode(project ?? WatchLine.key(of: projectName), forKey: .project)
        try row.encode(name, forKey: .name)
        try row.encode(projectName, forKey: .projectName)
        try row.encode(second ?? (isAway ? WatchLine.awayLine : "\(projectName) · \(name)"), forKey: .second)
    }
}
