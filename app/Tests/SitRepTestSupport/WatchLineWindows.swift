extension WatchLine {
    /// A live window, and the session it holds.
    public struct Window: Encodable, Sendable {
        /// What the window is doing, and since when.
        public struct State: Encodable, Sendable {
            public enum Kind: String, Encodable, Sendable {
                case working, permission, question, onItsWork, yourTurn
            }

            /// A tool: its name, and what it acts on.
            public struct Tool: Encodable, Sendable {
                public var name: String
                @OrNull public var subject: String?

                public init(name: String, subject: String? = nil) {
                    self.name = name
                    self.subject = subject
                }
            }

            /// The first question's text, and how many were asked.
            public struct Question: Encodable, Sendable {
                public var text: String
                public var count: Int

                public init(text: String, count: Int = 1) {
                    self.text = text
                    self.count = count
                }
            }

            public var `is`: Kind
            public var since: Int
            @OrNull public var tool: Tool?
            @OrNull public var question: Question?

            public init(_ kind: Kind, since: Int = 1_792_440_000_000, tool: Tool? = nil, question: Question? = nil) {
                self.is = kind
                self.since = since
                self.tool = tool
                self.question = question
            }
        }

        public var writer: String
        public var session: String
        /// The session's name, and its project's.
        public var name: String
        public var project: String
        /// The sitrep it runs.
        @OrNull public var version: String?
        public var needsReload: Bool
        @OrNull public var `where`: Where?
        /// The folder its Claude runs in.
        @OrNull public var directory: String?
        @OrNull public var state: State?
        public var attachedAt: Int
        /// Its place in the order a jump tries its session's windows, 0 first.
        @OrNull public var jumpOrder: Int?

        public init(
            writer: String = "b1c2d3e4-0000-4000-8000-000000000001", session: String = "sr-nw0001",
            name: String = "Ledger export", project: String = "Northwind", version: String? = "0.1.0",
            needsReload: Bool = false, where: Where? = nil, directory: String? = nil, state: State? = nil,
            attachedAt: Int = 1_792_440_000_000, jumpOrder: Int? = nil
        ) {
            self.writer = writer
            self.session = session
            self.name = name
            self.project = project
            self.version = version
            self.needsReload = needsReload
            self.where = `where`
            self.directory = directory
            self.state = state
            self.attachedAt = attachedAt
            self.jumpOrder = jumpOrder
        }
    }

    /// Where a window is: the terminal device Claude Code is on, the terminal program, its tmux pane, its zmx session.
    public struct Where: Encodable, Sendable {
        public struct Tmux: Encodable, Sendable {
            public var socket: String
            public var pane: String

            public init(socket: String = "/private/tmp/tmux-501/default", pane: String) {
                self.socket = socket
                self.pane = pane
            }
        }

        public struct Zmx: Encodable, Sendable {
            public var session: String

            public init(session: String) {
                self.session = session
            }
        }

        @OrNull public var device: String?
        @OrNull public var terminal: String?
        @OrNull public var tmux: Tmux?
        @OrNull public var zmx: Zmx?

        public init(device: String? = nil, terminal: String? = "ghostty", tmux: Tmux? = nil, zmx: Zmx? = nil) {
            self.device = device
            self.terminal = terminal
            self.tmux = tmux
            self.zmx = zmx
        }
    }
}
