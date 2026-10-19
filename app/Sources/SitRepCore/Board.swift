import Foundation

/// The board as every surface shows it: a line of `sitrep watch`, which
/// prints one at its start and another whenever the board changes
/// (cli/output.ts's `watchLine`). Finished sessions are not on it; away
/// ones are, their asks still counting.
public struct Board: Versioned, Sendable, Equatable {
    static let version = 1

    /// When the line was printed.
    public let at: Date
    /// The CLI's own version, which a window behind needs `/reload-plugins` to catch up to.
    public let version: String?
    public let head: Head
    /// The panel's, the strip's and the menu's rows, in their order.
    public let rows: [Row]
    /// Those with a current session, in the SitRep window's order.
    public let projects: [Project]
    /// Every live window, the longest attached first, a finished session's among them.
    public let windows: [Window]
    /// The keys of the rows needing Lee that the last line had not: the
    /// notch's swell, the strip's flash. None on the first line.
    public let new: [String]
    /// The sessions whose `board --json` changed since the last line, for the SitRep window to read again.
    public let changed: [String]

    /// How many rows need Lee, away ones among them, and how many sessions the rows hold.
    public struct Head: Decodable, Sendable, Equatable {
        public let needYou: Int
        public let sessions: Int

        /// None needing Lee: "All clear".
        public var isAllClear: Bool { needYou == 0 }
    }

    public struct Row: Decodable, Sendable, Equatable, Identifiable {
        public enum Kind: String, Decodable, Sendable {
            case ask, permission, question, yourTurn, working
        }

        /// A row's first line, in parts: `lead`, which a working row
        /// shimmers; `mono`, the subject set in mono; `more`, a question's `+2`.
        public struct Line: Decodable, Sendable, Equatable {
            public let lead: String
            public let mono: String?
            public let more: String?
        }

        /// Names the row for as long as it stands, so a view keeps its place by it.
        public let key: String
        public let kind: Kind
        /// An ask of a session no window holds.
        public let isAway: Bool
        public let session: String
        /// Its project's key.
        public let project: String
        /// The strip's two letters for its project.
        public let letters: String
        /// The ask it is, by its id; nil for a window's row.
        public let ask: String?
        /// The window it is of, by its writer; nil for an ask's row.
        public let writer: String?
        public let first: Line
        /// The project and the session.
        public let second: String
        /// The instant its time counts from, which the views tick.
        public let since: Date

        public var id: String { key }

        private enum CodingKeys: String, CodingKey {
            case key, kind = "is", isAway, session, project, letters, ask, writer, first, second, since
        }
    }

    public struct Project: Decodable, Sendable, Equatable, Identifiable {
        public let key: String
        public let name: String
        public let directory: String?
        public let open: Int
        public let waiting: Int
        public let parked: Int
        public let updatedAt: Date
        public let sessions: [Session]

        public var id: String { key }
    }

    /// A session as `list --json` gives it, with its state and the asks waiting on Lee.
    public struct Session: Decodable, Sendable, Equatable, Identifiable {
        public enum State: String, Decodable, Sendable {
            case needsYou, working, yourTurn, away, finished
        }

        public let id: String
        public let name: String
        public let summary: String
        public let now: [String]
        public let next: String?
        public let isOpen: Bool
        public let waiting: Int
        public let parked: Int
        public let updatedAt: Date
        public let state: State
        /// When its state began: its first row's time, else its latest line's.
        public let since: Date
        /// Oldest first.
        public let asks: [Ask]
    }

    /// An ask as `board --json` gives it.
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
                case working, permission, question, yourTurn
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
