import Darwin
import SitRepCore

/// A multiplexer adapter, one for each multiplexer a window may run in (tmux, zmx): from where a window is, the clients
/// showing its session, and for tmux the select that makes a client show its pane. Each client then goes through the
/// one step every multiplexer's does (`Processes.seat`): the terminal app its ancestry finds, and the device of that
/// app's own child. For the read of here, each client also gives a viewer (`Viewing`), and each session's ttys map to
/// its clients, for the board in a terminal to find its own. Another multiplexer is one more adapter, beside its field
/// in `Board.Window.Where`.
///
/// A window that records two, one run inside the other, is in the innermost: the one whose own pty is the window's
/// device, where one can tell; else each that cannot tell, never one that says its pty is another.
public protocol Multiplexer: Sendable {
    /// Whether a window runs in it, as its heartbeat says.
    func isIn(_ where: Board.Window.Where) -> Bool
    /// Whether it tells its clients by a process's command line, so the table reads that one's.
    func tellsBy(_ process: Proc) -> Bool
    /// Whether it tells its sessions' ttys by a process's command line, so the read of here has the table read that
    /// one's too: the jump's own read never needs them.
    func tellsTtysBy(_ process: Proc) -> Bool
    /// Reads what it needs for the windows that run in it, each program within its limit; nothing that fails here
    /// fails the read.
    func read(_ windows: [Board.Window.Where]) async -> any Reading
}

/// What a multiplexer read of the screen, for the windows in it.
public protocol Reading: Sendable {
    func isIn(_ where: Board.Window.Where) -> Bool
    /// Whether the window's device is this multiplexer's own pty for it, so the innermost of those it runs in; nil
    /// where that cannot be told.
    func isOnItsPty(_ where: Board.Window.Where) -> Bool?
    /// The places showing a window in it, or that a select would make show it, its clients seated by the table; none
    /// for a window not in it.
    func places(_ where: Board.Window.Where, _ processes: Processes) -> [Place]
    /// The clients showing a window in it, or that a select would make show it, wherever they are: those `places`
    /// seats, and those it seats in no app. None for a window not in it.
    func clients(_ where: Board.Window.Where, _ processes: Processes) -> [Client]
    /// Each pty inside a session it read, by its device, and the clients showing that session: every session, those
    /// holding no Claude among them.
    func ttys(_ processes: Processes) -> [String: [Client]]
    /// What it asked that gave no answer, for the window.
    func unanswered(_ where: Board.Window.Where) -> [Unanswered]
    /// Whether the window's clients are told only by the process table: whether the table giving no answer leaves
    /// where the window shows unknown.
    func needsProcesses(_ where: Board.Window.Where) -> Bool
}

/// A client showing a session: a multiplexer's client, or a process on a terminal holding Claude in none. Its process,
/// and its own device, nil or empty for none.
public struct Client: Sendable, Hashable {
    public let pid: pid_t
    public let device: String?

    public init(pid: pid_t, device: String?) {
        self.pid = pid
        self.device = device
    }
}

/// What gave no answer, so that showing nowhere may mean only not knowing.
public enum Unanswered: Sendable, Hashable {
    case tmux
    /// tmux answering with an error other than no server, in its words: a server it could not talk to.
    case tmuxSaid(String)
    /// The kernel's process table, which only `sysctl` failing outright leaves unread.
    case processes
}

/// A select: the tmux window to make current in a tmux session, by their ids, on the server at the socket.
public struct Select: Sendable, Hashable {
    public let socket: String
    public let session: String
    public let window: String

    public init(socket: String, session: String, window: String) {
        self.socket = socket
        self.session = session
        self.window = window
    }
}

/// Where a jump can bring a window forward: the terminal app, the device of its window there, which only an app with
/// no driver may lack, and the select that makes that window show the pane first, where tmux must make one.
public struct Place: Sendable, Hashable {
    public let app: TerminalApp
    public let device: String?
    public let select: Select?

    public init(app: TerminalApp, device: String?, select: Select? = nil) {
        self.app = app
        self.device = device
        self.select = select
    }

    init(_ seat: Seat, select: Select? = nil) {
        self.init(app: seat.app, device: seat.device, select: select)
    }
}
