import Foundation
import os

/// The board as every surface shows it: a line of `sitrep watch`, which
/// prints one at its start and another whenever the board changes or it
/// carries a board of a session the window follows (cli/output.ts's
/// `watchLine`). Finished sessions are not on it; away ones are, their asks
/// still counting.
public struct Board: Versioned, Sendable, Equatable {
    static let version = 3

    /// When the line was printed.
    public let at: Date
    /// The CLI's own version, which a window behind needs `/reload-plugins` to catch up to.
    public let version: String?
    public let head: Head
    /// The panel's, the strip's, the menu's and the sidebar's rows, a session each, in their order.
    public let rows: [Row]
    /// The card's and the sidebar's Snoozed rows, a session each, the soonest to wake first: apart from `rows`, as a
    /// session may have one in both. None from a CLI before Snooze.
    public let snoozed: [SnoozedRow]
    /// Those with a current session, in the SitRep window's order.
    public let projects: [Project]
    /// Every live window, the longest attached first, a finished session's among them.
    public let windows: [Window]
    /// The keys of the lines needing Lee that the last line had not, an ask's or a window's stop: the notch's swell,
    /// the strip's flash. None on the first line.
    public let new: [String]
    /// By session id, the board of each session the window follows that is new to what it follows or changed since
    /// the watch last printed it, folded as the line is. Each is printed once, so only the line that carries it says
    /// it.
    public let boards: [String: Carried]

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
        projects = try given.decode([Project].self, forKey: .projects)
        windows = try given.decode([Window].self, forKey: .windows)
        new = try given.decode([String].self, forKey: .new)
        boards = try given.decode([String: Carried].self, forKey: .boards)
    }

    private enum CodingKeys: String, CodingKey {
        case at, version, head, rows, snoozed, projects, windows, new, boards
    }

    /// A session's board as a line carries it, each read on its own, so one this app cannot read leaves the rest of
    /// the line to read.
    public enum Carried: Decodable, Sendable, Equatable {
        case board(SessionBoard)
        /// The watch finds no such session: none a project files, or one whose `session.json` does not fold.
        case notFound
        /// A board this app cannot read.
        case unread

        /// The board, where it was found and reads.
        public var board: SessionBoard? {
            if case let .board(board) = self {
                return board
            }
            return nil
        }

        public init(from decoder: any Decoder) throws {
            if try decoder.singleValueContainer().decodeNil() {
                self = .notFound
                return
            }

            do {
                self = .board(try SessionBoard(from: decoder))
            } catch {
                Logger.watch.error("sitrep watch carried a board this SitRep cannot read: \(error, privacy: .public)")
                self = .unread
            }
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

    /// A session's row in Snoozed: its asks Lee snoozed, a line each, the soonest to wake first, then the oldest; and
    /// when the soonest wakes. Its session, project and names as a Needs you row's.
    public struct SnoozedRow: Decodable, Sendable, Equatable, Identifiable {
        /// One of its asks: its key, the one it has in Needs you; the ask by its id; its title; the instant its time
        /// counts from; and when it wakes.
        public struct Line: Decodable, Sendable, Equatable, Identifiable {
            public let key: String
            public let ask: String
            public let first: Row.Words
            public let since: Date
            public let wakesAt: Date

            public var id: String { key }
        }

        public let session: String
        public let isAway: Bool
        public let project: String
        public let name: String
        public let projectName: String
        public let letters: String
        public let lines: [Line]
        public let second: String
        /// When its soonest line wakes.
        public let wakesAt: Date

        public var id: String { session }

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
            wakesAt = try given.decode(Date.self, forKey: .wakesAt)
            guard !lines.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .lines, in: given, debugDescription: "A row has a line.")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case session, isAway, project, name, projectName, letters, lines, second, wakesAt
        }
    }

    public struct Project: Decodable, Sendable, Equatable, Identifiable {
        public let key: String
        public let name: String
        public let directory: String?
        public let open: Int
        public let waiting: Int
        /// Its asks snoozed; none from a CLI before Snooze.
        @Added public var snoozed: Int
        public let parked: Int
        public let updatedAt: Date
        public let sessions: [Session]

        public var id: String { key }
    }

    /// A session as `list --json` gives it, with its state, what it is doing, its open asks (waiting, on Lee or on a
    /// window to deliver Lee's reply, or replied, Claude's to act on) and what it parked.
    public struct Session: Decodable, Sendable, Equatable, Identifiable {
        public enum State: String, Decodable, Sendable {
            case needsYou, working, onItsWork, yourTurn, away, finished
        }

        /// What a session is doing, as the line under its name says it: a window's permission prompt or question,
        /// else its window working, on its own work or waiting on Lee's message, each as its row's first line, since
        /// its state began; else away, since its latest line.
        public struct Doing: Decodable, Sendable, Equatable {
            public enum Kind: String, Decodable, Sendable {
                case permission, question, working, onItsWork, yourTurn, away
            }

            public let kind: Kind
            public let line: Row.Words
            public let since: Date

            private enum CodingKeys: String, CodingKey {
                case kind = "is", line, since
            }
        }

        public let id: String
        public let name: String
        public let summary: String
        public let now: [String]
        public let next: String?
        public let isOpen: Bool
        public let waiting: Int
        /// Its asks snoozed; none from a CLI before Snooze.
        @Added public var snoozed: Int
        public let parked: Int
        /// When it started; nil from a CLI before the feed said it.
        public let created: Date?
        public let updatedAt: Date
        public let state: State
        /// When its state began: its first row's time, else its latest line's.
        public let since: Date
        public let doing: Doing
        /// Oldest first.
        public let asks: [Ask]
        /// What it parked, oldest first; none from a CLI before the feed carried them.
        @Added public var parkedItems: [SessionBoard.Parked]
    }

    /// An ask as a session's board gives it.
    public struct Ask: Decodable, Sendable, Equatable, Identifiable {
        public enum Wants: String, Decodable, Sendable {
            case yes, choice, words
        }

        public enum State: String, Decodable, Sendable {
            case waiting, replied, closed, ignored
        }

        public let id: String
        public let wants: Wants
        /// The yes button's words, on an ask that wants a yes.
        public let yes: String?
        public let title: String
        public let `where`: String?
        public let options: [String]
        public let needs: String?
        public let ref: String?
        public let state: State
        public let at: Date
        /// Where Lee's reply to it stands; nil with none sent, one gone void as it was edited under it, or only a
        /// comment Claude has.
        public let reply: Reply?
        /// When Lee's snooze of it wakes it, while one holds on it as it waits on Lee; nil from a CLI before Snooze.
        public let snoozedUntil: Date?
    }

    /// Where Lee's reply to an ask stands, as core's `replyState` says: on its way, in the session's inbox; with
    /// Claude; or never delivered, as Claude closed the ask first.
    public struct Reply: Decodable, Sendable, Equatable {
        public enum Standing: String, Decodable, Sendable {
            case onItsWay, delivered, notDelivered
        }

        public let standing: Standing
        /// It is Lee's answer, which bars another, and not a comment, which bars nothing.
        public let isAnswer: Bool
        /// The reply as the board shows it on one row: `→ Go`, `ignored`, `comment: “Tighten the copy”`.
        public let words: String
        /// When it last moved: delivered, gone void, or else sent.
        public let since: Date

        private enum CodingKeys: String, CodingKey {
            case standing = "is", isAnswer, words, since
        }
    }

    /// A live window, and the session it holds.
    public struct Window: Decodable, Sendable, Equatable, Identifiable {
        /// The terminal device Claude Code is on, the terminal program, and its tmux pane when it runs in tmux.
        public struct Where: Decodable, Sendable, Equatable {
            public struct Tmux: Decodable, Sendable, Equatable {
                public let socket: String
                public let pane: String
            }

            public let device: String?
            /// `$TERM_PROGRAM` as given: `ghostty`, `tmux`, `iTerm.app`.
            public let terminal: String?
            public let tmux: Tmux?
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

        public var id: String { writer }
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

extension Int: AddedValue {
    public static var absent: Int { 0 }
}

extension Array: AddedValue where Element: Decodable & Equatable {
    public static var absent: [Element] { [] }
}

extension KeyedDecodingContainer {
    /// An added field, or none where the output is from before it.
    func decode<Value>(_ type: Added<Value>.Type, forKey key: Key) throws -> Added<Value> {
        try decodeIfPresent(type, forKey: key) ?? Added(wrappedValue: .absent)
    }
}
