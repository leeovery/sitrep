import Foundation

/// The board as every surface shows it: a line of `sitrep watch`, which
/// prints one at its start and another whenever the board changes
/// (cli/output.ts's `watchLine`). Finished sessions are not on it; away ones
/// are, their asks still counting. Only what the app shows is read, so a
/// change to the rest of the line leaves the board reading.
public struct Board: Versioned, Sendable, Equatable {
    static let version = 3

    /// When the line was printed.
    public let at: Date
    /// The CLI's own version, which a window behind needs `/reload-plugins` to catch up to.
    public let version: String?
    public let head: Head
    /// The panel's, the strip's and the menu's rows, a session each, in their order.
    public let rows: [Row]
    /// The card's Snoozed rows, a session each, the soonest to wake first: apart from `rows`, as a
    /// session may have one in both. None from a CLI before Snooze.
    public let snoozed: [SnoozedRow]
    /// Every live window, the longest attached first, a finished session's among them.
    public let windows: [Window]
    /// The keys of the lines needing Lee that the last line had not, an ask's or a window's stop: the notch's swell,
    /// the strip's flash. None on the first line.
    public let new: [String]
    /// Every session the projects list, a current one each, row or none, by its id: their names alone, which a jump
    /// names a session by. Read in any shape or none, as no surface shows the projects: a line whose projects do not
    /// read names none.
    let named: [String: String]
    /// The window each away session was last in, by its id, which a click carries it on from; read as the names are.
    let lastWindows: [String: LastWindow]
    /// Each session's open asks, by its id, in the line's order; read as the names are, an ask that does not read left
    /// out.
    let asks: [String: [Ask]]

    /// The rows holding a line new on this board, by their sessions.
    public var newRows: Set<String> {
        let new = Set(self.new)

        return Set(rows.filter { $0.lines.contains { new.contains($0.key) } }.map(\.session))
    }

    public init(from decoder: any Decoder) throws {
        let given = try decoder.container(keyedBy: CodingKeys.self)

        at = try given.decode(Date.self, forKey: .at)
        version = try given.decodeIfPresent(String.self, forKey: .version)
        head = try given.decode(Head.self, forKey: .head)
        rows = try given.decode([Row].self, forKey: .rows)
        snoozed = try given.decodeIfPresent([SnoozedRow].self, forKey: .snoozed) ?? []
        windows = try given.decode([Window].self, forKey: .windows)
        new = try given.decode([String].self, forKey: .new)

        let sessions = (try? given.decodeIfPresent([Project].self, forKey: .projects))?.flatMap(\.sessions) ?? []

        named = sessions.reduce(into: [:]) { $0[$1.id] = $1.name }
        lastWindows = sessions.reduce(into: [:]) { $0[$1.id] = $1.lastWindow }
        asks = sessions.reduce(into: [:]) { $0[$1.id] = $1.asks }
    }

    private enum CodingKeys: String, CodingKey {
        case at, version, head, rows, snoozed, windows, new, projects
    }

    /// A project, for the names of its sessions, the windows its away ones were last in, and their asks.
    private struct Project: Decodable {
        struct Session: Decodable {
            let id: String
            let name: String
            /// None from a CLI from before the watch carried it (12 November 2026), or in a shape that does not read.
            let lastWindow: LastWindow?
            let asks: [Ask]

            init(from decoder: any Decoder) throws {
                let given = try decoder.container(keyedBy: CodingKeys.self)

                id = try given.decode(String.self, forKey: .id)
                name = try given.decode(String.self, forKey: .name)
                lastWindow = try? given.decodeIfPresent(LastWindow.self, forKey: .lastWindow)
                asks = (try? given.decodeIfPresent([Readable<Ask>].self, forKey: .asks))?.compactMap(\.value) ?? []
            }

            private enum CodingKeys: String, CodingKey {
                case id, name, lastWindow, asks
            }
        }

        let sessions: [Session]
    }

    /// An open ask of a session, as the asks panel and a new ask's banner answer it: what it wants back, a yes's one
    /// button or a choice's options, Claude's pick among them, what a words ask needs, when it was posted, and where
    /// Lee's reply to it stands.
    public struct Ask: Decodable, Sendable, Equatable, Identifiable {
        public enum Wants: String, Decodable, Sendable {
            case yes, choice, words
        }

        /// Where Lee's reply to it stands: on its way to the session, delivered, or not delivered, Claude having
        /// closed the ask first; whether it is his answer, not a comment; its words as the board shows them on one
        /// row; and since when.
        public struct Reply: Decodable, Sendable, Equatable {
            public enum Kind: String, Decodable, Sendable {
                case onItsWay, delivered, notDelivered
            }

            public let kind: Kind
            public let isAnswer: Bool
            public let words: String?
            public let since: Date

            private enum CodingKeys: String, CodingKey {
                case kind = "is", isAnswer, words, since
            }
        }

        public let id: String
        public let wants: Wants
        /// A yes ask's button's words; nil for any other.
        public let yes: String?
        public let title: String
        /// A choice's options, in Claude's order; none for any other ask.
        public let options: [String]
        /// The option Claude recommends; none from a CLI from before asks said it.
        public let recommended: String?
        /// What a words ask needs of Lee.
        public let needs: String?
        /// When it was posted.
        public let at: Date
        /// None where Lee has sent none, and from a CLI from before the watch said it.
        public let reply: Reply?
        private let state: String

        /// Waiting on Lee, with no reply of his on its way, as core's `waitsOnLee` has it: an ask he can answer.
        public var waitsOnLee: Bool { state == "waiting" && reply?.kind != .onItsWay }

        public init(from decoder: any Decoder) throws {
            let given = try decoder.container(keyedBy: CodingKeys.self)

            id = try given.decode(String.self, forKey: .id)
            wants = try given.decode(Wants.self, forKey: .wants)
            yes = try given.decodeIfPresent(String.self, forKey: .yes)
            title = try given.decode(String.self, forKey: .title)
            options = try given.decodeIfPresent([String].self, forKey: .options) ?? []
            recommended = try given.decodeIfPresent(String.self, forKey: .recommended)
            needs = try given.decodeIfPresent(String.self, forKey: .needs)
            at = try given.decode(Date.self, forKey: .at)
            reply = try given.decodeIfPresent(Reply.self, forKey: .reply)
            state = try given.decode(String.self, forKey: .state)
        }

        private enum CodingKeys: String, CodingKey {
            case id, wants, yes, title, options, recommended, needs, at, reply, state
        }
    }

    /// The window an away session was last in, by its heartbeat last seen: its writer, the Claude Code session it ran,
    /// which a `/clear` moves on; where it was, as its heartbeat said, its device among it; whether its device is still
    /// its conversation's, none from a line that does not say; and the folder its Claude ran in, none from a window on a
    /// sitrep from before heartbeats said it. The live window a click carries a held session on from is one too, its
    /// device its own.
    public struct LastWindow: Decodable, Sendable, Equatable {
        public let writer: String
        public let `where`: Window.Where?
        public let ownsDevice: Bool?
        public let directory: String?

        public init(writer: String, where: Window.Where? = nil, ownsDevice: Bool? = nil, directory: String? = nil) {
            self.writer = writer
            self.where = `where`
            self.ownsDevice = ownsDevice
            self.directory = directory
        }
    }

    /// How many lines need Lee, away ones among them, and how many sessions the rows hold.
    public struct Head: Decodable, Sendable, Equatable {
        public let needYou: Int
        public let sessions: Int

        /// None needing Lee: "All clear".
        public var isAllClear: Bool { needYou == 0 }
    }

    /// A session's row: in Needs you, a line for each ask and stop waiting on Lee, the oldest first; else the one line
    /// of its turn, working, on its own work or your turn. Never without a line.
    public struct Row: Decodable, Sendable, Equatable, Identifiable {
        public enum Section: String, Decodable, Sendable {
            case needsYou, working, yourTurn
        }

        /// A line's words, in parts: `lead`, which a working line shimmers; `mono`, the subject set in mono where it
        /// is a command or a path; `subject`, set plain where it is not; `more`, a question's `+2`; `until`, when the
        /// wake a line on its own work waits on is due, which the views count down to after the lead.
        public struct Words: Decodable, Sendable, Equatable {
            public let lead: String
            public let mono: String?
            public let subject: String?
            public let more: String?
            public let until: Date?

            init(lead: String, mono: String? = nil, subject: String? = nil, more: String? = nil, until: Date? = nil) {
                self.lead = lead
                self.mono = mono
                self.subject = subject
                self.more = more
                self.until = until
            }
        }

        /// One of a row's lines: an ask or a window's stop waiting on Lee, or the session's turn.
        public struct Line: Decodable, Sendable, Equatable, Identifiable {
            public enum Kind: String, Decodable, Sendable {
                case ask, permission, question, yourTurn, working, onItsWork
            }

            /// Names the line for as long as it stands: an ask's, a window's stop's, or the session's turn.
            public let key: String
            public let kind: Kind
            /// The ask it is, by its id; nil for a window's line.
            public let ask: String?
            /// The window it is of, by its writer; nil for an ask's line.
            public let writer: String?
            public let first: Words
            /// The instant its time counts from, which the views tick.
            public let since: Date

            public var id: String { key }

            private enum CodingKeys: String, CodingKey {
                case key, kind = "is", ask, writer, first, since
            }
        }

        public let session: String
        public let section: Section
        /// Needing Lee, with no window holding its session.
        public let isAway: Bool
        /// Its project's key.
        public let project: String
        /// Its session's name, which a Needs you row shows as its title.
        public let name: String
        /// Its project's name, which a Needs you row shows under its title.
        public let projectName: String
        /// The strip's two letters for its project.
        public let letters: String
        /// Needing Lee, the newest first; else its one.
        public let lines: [Line]
        /// The project and the session, under a Working or Your turn row's line; an away row's says no window holds it.
        public let second: String
        /// The instant its time counts from, its newest line's, which the views tick.
        public let since: Date

        public var id: String { session }

        /// Its newest line, which a surface with room for one line shows.
        public var newest: Line { lines[0] }

        /// In Needs you: its lines are asks, permission prompts or questions.
        public var needsLee: Bool { section == .needsYou }

        public init(from decoder: any Decoder) throws {
            let given = try decoder.container(keyedBy: CodingKeys.self)

            session = try given.decode(String.self, forKey: .session)
            section = try given.decode(Section.self, forKey: .section)
            isAway = try given.decode(Bool.self, forKey: .isAway)
            project = try given.decode(String.self, forKey: .project)
            name = try given.decode(String.self, forKey: .name)
            projectName = try given.decode(String.self, forKey: .projectName)
            letters = try given.decode(String.self, forKey: .letters)
            lines = try given.decode([Line].self, forKey: .lines)
            second = try given.decode(String.self, forKey: .second)
            since = try given.decode(Date.self, forKey: .since)
            guard !lines.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .lines, in: given, debugDescription: "A row has a line.")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case session, section, isAway, project, name, projectName, letters, lines, second, since
        }
    }

    /// A session's row in Snoozed: its asks Lee snoozed, a line each, the soonest to wake first, then the oldest, or its
    /// turn Lee snoozed, a row of its own; and when the soonest wakes, nil for a turn snoozed until it moves. Its
    /// session, project and names as a Needs you row's.
    public struct SnoozedRow: Decodable, Sendable, Equatable, Identifiable {
        /// One of its lines: its key, the one it has in Needs you, or in Your turn for a turn; what it is; the ask by
        /// its id, nil for a turn; its words; the instant its time counts from; and when it wakes, nil for a turn
        /// snoozed until it moves.
        public struct Line: Decodable, Sendable, Equatable, Identifiable {
            public enum Kind: String, Decodable, Sendable, AddedValue {
                case ask, yourTurn

                /// A CLI from before a turn could be snoozed held asks alone in Snoozed.
                public static var absent: Kind { .ask }
            }

            public let key: String
            @Added public var kind: Kind
            public let ask: String?
            public let first: Row.Words
            public let since: Date
            public let wakesAt: Date?

            public var id: String { key }

            private enum CodingKeys: String, CodingKey {
                case key, kind = "is", ask, first, since, wakesAt
            }
        }

        public let session: String
        public let isAway: Bool
        public let project: String
        public let name: String
        public let projectName: String
        public let letters: String
        public let lines: [Line]
        public let second: String
        /// When its soonest line wakes; nil for a turn snoozed until it moves.
        public let wakesAt: Date?

        /// Its session's turn, not its asks.
        public var isTurn: Bool { lines.allSatisfy { $0.kind == .yourTurn } }

        /// A session's two rows in Snoozed, its asks' and its turn's, are each its own.
        public var id: String { isTurn ? "turn:\(session)" : session }

        public init(from decoder: any Decoder) throws {
            let given = try decoder.container(keyedBy: CodingKeys.self)

            session = try given.decode(String.self, forKey: .session)
            isAway = try given.decode(Bool.self, forKey: .isAway)
            project = try given.decode(String.self, forKey: .project)
            name = try given.decode(String.self, forKey: .name)
            projectName = try given.decode(String.self, forKey: .projectName)
            letters = try given.decode(String.self, forKey: .letters)
            lines = try given.decode([Line].self, forKey: .lines)
            second = try given.decode(String.self, forKey: .second)
            wakesAt = try given.decodeIfPresent(Date.self, forKey: .wakesAt)
            guard !lines.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .lines, in: given, debugDescription: "A row has a line.")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case session, isAway, project, name, projectName, letters, lines, second, wakesAt
        }
    }

    /// A live window, and the session it holds.
    public struct Window: Decodable, Sendable, Equatable, Identifiable {
        /// The terminal device Claude Code is on, the terminal program, its tmux pane when it runs in tmux, and its zmx
        /// session when it runs in zmx.
        public struct Where: Decodable, Sendable, Hashable {
            public struct Tmux: Decodable, Sendable, Hashable {
                public let socket: String
                /// tmux's id for the pane, `%148`.
                public let pane: String

                public init(socket: String, pane: String) {
                    self.socket = socket
                    self.pane = pane
                }
            }

            public struct Zmx: Decodable, Sendable, Hashable {
                /// `$ZMX_SESSION` whole, spaces and `·` kept: `kit · restore-card`.
                public let session: String

                public init(session: String) {
                    self.session = session
                }
            }

            public let device: String?
            /// `$TERM_PROGRAM` as given: `ghostty`, `tmux`, `iTerm.app`.
            public let terminal: String?
            public let tmux: Tmux?
            /// None from a CLI from before windows said it (9 November 2026).
            public let zmx: Zmx?

            public init(device: String? = nil, terminal: String? = nil, tmux: Tmux? = nil, zmx: Zmx? = nil) {
                self.device = device
                self.terminal = terminal
                self.tmux = tmux
                self.zmx = zmx
            }
        }

        /// What the window is doing, and since when.
        public struct State: Decodable, Sendable, Equatable {
            public enum Kind: String, Decodable, Sendable {
                case working, permission, question, onItsWork, yourTurn
            }

            /// A tool: its name, and what it acts on (a file's path, Bash's command).
            public struct Tool: Decodable, Sendable, Equatable {
                public let name: String
                public let subject: String?
            }

            /// The first question's text, and how many were asked.
            public struct Question: Decodable, Sendable, Equatable {
                public let text: String
                public let count: Int
            }

            public let kind: Kind
            public let since: Date
            /// The tool running while working; the one a permission prompt asks for.
            public let tool: Tool?
            public let question: Question?

            private enum CodingKeys: String, CodingKey {
                case kind = "is", since, tool, question
            }
        }

        public let writer: String
        public let session: String
        /// The session's name, and its project's.
        public let name: String
        public let project: String
        /// The sitrep it runs; nil from a window on a version before heartbeats said it.
        public let version: String?
        /// It runs a sitrep behind the CLI's own, or says none, and needs `/reload-plugins`.
        public let needsReload: Bool
        public let `where`: Where?
        public let state: State?
        public let attachedAt: Date
        /// Its place in the order a jump tries its session's windows, 0 first, as core ranks them; none for a window
        /// saying no `where`, which no jump tries, and from a CLI from before the watch carried it (9 November 2026).
        public let jumpOrder: Int?
        /// The folder its Claude runs in, as its heartbeat says it; none from a window on a sitrep from before
        /// heartbeats said it, and from a CLI from before the watch carried it (13 November 2026).
        public let directory: String?

        public var id: String { writer }
    }

    /// The session's windows a jump tries, by where each is, in core's order (`jumpOrder`), never by their place in
    /// `windows`; one with no order is not tried. A line from a watch before the order, whose windows carry none,
    /// gives every one saying where it is, in the line's order.
    public func jumpWindows(of session: String) -> [Window.Where] {
        inJumpOrder(of: session).compactMap(\.where)
    }

    /// Whether a live window holds the session.
    public func isHeld(_ session: String) -> Bool {
        windows.contains { $0.session == session }
    }

    /// The window a click carries the session on from where no terminal on this Mac shows it: of its live windows, the
    /// one a jump tries first, else the first listed, its device its own; with none, the window it was last in, as the
    /// line names it. Nil where it has neither.
    public func resumeWindow(of session: String) -> LastWindow? {
        guard let live = inJumpOrder(of: session).first ?? windows.first(where: { $0.session == session }) else {
            return lastWindows[session]
        }

        return LastWindow(writer: live.writer, where: live.where, ownsDevice: true, directory: live.directory)
    }

    /// The session's windows a jump tries, in its order; from a line before the order, every one saying where it is.
    private func inJumpOrder(of session: String) -> [Window] {
        let own = windows.filter { $0.session == session }

        guard windows.contains(where: { $0.jumpOrder != nil }) else {
            return own.filter { $0.where != nil }
        }

        return own
            .compactMap { window in window.jumpOrder.map { (order: $0, window: window) } }
            .sorted { $0.order < $1.order }
            .map(\.window)
    }

    /// The session's open asks, in the line's order; none for a session not on the board, nor from a line that does not
    /// carry them.
    public func asks(of session: String) -> [Ask] {
        asks[session] ?? []
    }

    /// An open ask of the session, by its id; nil for one not on the board, as a closed one is not.
    public func ask(_ id: String, of session: String) -> Ask? {
        asks(of: session).first { $0.id == id }
    }

    /// The session's name, as its row, its Snoozed row, a window of it or its project says; nil for a session not on
    /// the board, as a finished one holding no window is not.
    public func name(of session: String) -> String? {
        rows.first { $0.session == session }?.name
            ?? snoozed.first { $0.session == session }?.name
            ?? windows.first { $0.session == session }?.name
            ?? named[session]
    }
}

/// A value of a list that reads, or none for one that does not, so one the app cannot read leaves the rest read.
private struct Readable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// A field the CLI's JSON gained after its version was set, `v` unmoved: none in the output of a CLI from before it.
@propertyWrapper
public struct Added<Value: AddedValue>: Decodable, Equatable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        wrappedValue = try decoder.singleValueContainer().decode(Value.self)
    }
}

extension Added: Sendable where Value: Sendable {}

/// What an added field reads as where the output is from a CLI before it.
public protocol AddedValue: Decodable, Equatable {
    static var absent: Self { get }
}

extension KeyedDecodingContainer {
    /// An added field, or none where the output is from before it.
    func decode<Value>(_ type: Added<Value>.Type, forKey key: Key) throws -> Added<Value> {
        try decodeIfPresent(type, forKey: key) ?? Added(wrappedValue: .absent)
    }
}
