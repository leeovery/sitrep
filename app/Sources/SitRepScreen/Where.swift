/// Where a window is, as its heartbeat records it (core's `Where`): the terminal device Claude Code is on, the terminal
/// program, its tmux socket and pane when it runs in tmux, and its zmx session when it runs in zmx.
public struct Where: Sendable, Hashable {
    public struct Tmux: Sendable, Hashable {
        public let socket: String
        /// tmux's id for the pane, `%148`.
        public let pane: String

        public init(socket: String, pane: String) {
            self.socket = socket
            self.pane = pane
        }
    }

    public struct Zmx: Sendable, Hashable {
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
    public let zmx: Zmx?

    public init(device: String? = nil, terminal: String? = nil, tmux: Tmux? = nil, zmx: Zmx? = nil) {
        self.device = device
        self.terminal = terminal
        self.tmux = tmux
        self.zmx = zmx
    }
}

/// Whether a value is a terminal device, `/dev/ttys043`: only a tty, the form Ghostty's terminals give as their `tty`.
/// tmux gives a control-mode client over pipes an empty one.
public func isDevice(_ value: String?) -> Bool {
    let tty = "/dev/tty"

    guard let value, value.hasPrefix(tty) else {
        return false
    }

    let name = value.dropFirst(tty.count)

    return !name.isEmpty && name.allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) }
}
