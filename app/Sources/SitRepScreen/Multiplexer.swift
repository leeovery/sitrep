import SitRepCore

/// A multiplexer adapter, one for each multiplexer a window may run in (tmux, zmx): from where a window is, the clients
/// showing its session, and for tmux the select that makes a client show its pane. Each client then goes through the
/// one step every multiplexer's does (`Processes.seat`): the terminal app its ancestry finds, and the device of that
/// app's own child. Another multiplexer is one more adapter, beside its field in `Board.Window.Where`.
///
/// A window that records two, one run inside the other, is in the innermost: the one whose own pty is the window's
/// device, where one can tell; else each that cannot tell, never one that says its pty is another.
public protocol Multiplexer: Sendable {
    var kind: MultiplexerKind { get }
    /// Whether a window runs in it, as its heartbeat says.
    func isIn(_ where: Board.Window.Where) -> Bool
    /// Whether it tells its clients by a process's command line, so the table reads that one's.
    func tellsBy(_ process: Proc) -> Bool
    /// Reads what it needs for the windows that run in it, each program within its limit; nothing that fails here
    /// fails the read.
    func read(_ windows: [Board.Window.Where]) async -> any Reading
    /// The facts wanted of those its window records (`MultiplexerKind.facts`), for a window in it: what can change
    /// under the window asked of the multiplexer now, the rest from the heartbeat. Throws, in plain words (its
    /// description), where what it was asked gave no answer.
    func facts(of where: Board.Window.Where, wanted: Set<Fact>) async throws -> [Fact: String]
}

/// What a multiplexer read of the screen, for the windows in it.
public protocol Reading: Sendable {
    var kind: MultiplexerKind { get }
    func isIn(_ where: Board.Window.Where) -> Bool
    /// Whether it holds the window's session alive, so a window attaching to it would show it.
    func holds(_ where: Board.Window.Where) -> Bool
    /// Whether the window's device is this multiplexer's own pty for it, so the innermost of those it runs in; nil
    /// where that cannot be told.
    func isOnItsPty(_ where: Board.Window.Where) -> Bool?
    /// The places showing a window in it, or that a select would make show it, its clients seated by the table; none
    /// for a window not in it.
    func places(_ where: Board.Window.Where, _ processes: Processes) -> [Place]
    /// What it asked that gave no answer, for the window.
    func unanswered(_ where: Board.Window.Where) -> [Unanswered]
    /// Whether the window's clients are told only by the process table: whether the table giving no answer leaves
    /// where the window shows unknown.
    func needsProcesses(_ where: Board.Window.Where) -> Bool
}

/// A multiplexer, as a window runs in one.
public enum MultiplexerKind: String, Sendable, Hashable {
    case tmux, zmx

    /// The facts a window in it gives: a zmx session's name; a tmux server's socket, a pane's id and the name of the
    /// tmux session holding the pane.
    public var facts: [Fact] {
        switch self {
        case .zmx: [.session]
        case .tmux: [.session, .socket, .pane]
        }
    }
}

/// A fact of where a window runs, as its multiplexer gives it: its session's name, its tmux server's socket, its tmux
/// pane's id.
public enum Fact: String, Sendable, Hashable, CaseIterable {
    case session, socket, pane

    /// What it is in words, in a multiplexer: `the zmx session's name`.
    func words(in kind: MultiplexerKind) -> String {
        switch self {
        case .session: "the \(kind.rawValue) session's name"
        case .socket: "the \(kind.rawValue) socket's path"
        case .pane: "the \(kind.rawValue) pane's id"
        }
    }
}

/// What gave no answer, so that showing nowhere may mean only not knowing.
public enum Unanswered: String, Sendable, Hashable {
    case tmux
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
