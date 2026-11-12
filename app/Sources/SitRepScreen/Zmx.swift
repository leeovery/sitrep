import SitRepCore

/// zmx's multiplexer adapter. A zmx session is one terminal, shown whole by every client attached to it, so there is no
/// window or pane to select. zmx 1.0.1 lists no session's clients, so they are read from the process table: each
/// process of zmx's program, on a tty, whose command line is exactly `zmx attach <session>`, by any path to zmx, the
/// name compared whole, in order of process id: the oldest client first, until ids wrap round. The session's own server is on no tty, under launchd (live, 9
/// November 2026), so it is no client; its command line, a client's with any command it runs after, tells that the
/// session is alive, which an away session's last window needs told (stage 8), as no live window is there to prove it.
///
/// Only a process whose program's file is named `zmx` has its command line read, which keeps the reads to a few a look;
/// the CLI read every process's from `ps`. So a zmx installed under another name reads off screen.
///
/// A client switched in place, `zmx attach B` typed inside an attach on A, keeps A's name in its command line, and so
/// reads as A's: a known limit, as Portal's own switch starts a fresh `zmx attach B`.
public struct ZmxAdapter: Multiplexer {
    public init() {}

    public let kind = MultiplexerKind.zmx

    public func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.zmx != nil
    }

    /// A process of zmx's program, which may be a client, on a tty, or a session's server: only its command line tells
    /// whose.
    public func tellsBy(_ process: Proc) -> Bool {
        process.program?.split(separator: "/").last == "zmx"
    }

    /// zmx asks nothing of its own: its clients, and so which apps show its windows, are told by the table alone.
    public func read(_: [Board.Window.Where]) async -> any Reading {
        ZmxReading()
    }

    /// The session's name, the window's `$ZMX_SESSION`, fixed for the session's life: zmx renames nothing, and
    /// Portal's `rename` sets a label of its own. zmx is asked nothing.
    public func facts(of where: Board.Window.Where, wanted _: Set<Fact>) async -> [Fact: String] {
        `where`.zmx.map { [.session: $0.session] } ?? [:]
    }
}

struct ZmxReading: Reading {
    let kind = MultiplexerKind.zmx

    func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.zmx != nil
    }

    /// Whether the window's zmx session runs: a process of zmx's attaches to it, its server or a client. SitRep asks
    /// zmx nothing.
    func holds(_ where: Board.Window.Where, _ processes: Processes) -> Bool {
        guard let session = `where`.zmx?.session else {
            return false
        }

        return processes.arguments.values.contains { Self.attaches($0, to: session, running: true) }
    }

    /// zmx cannot tell its session's pty without a further program.
    func isOnItsPty(_: Board.Window.Where) -> Bool? {
        nil
    }

    /// Each client of the window's zmx session on a tty that a jump can reach, by its process's id, on the device of
    /// its terminal's own pty.
    func places(_ where: Board.Window.Where, _ processes: Processes) -> [Place] {
        guard let session = `where`.zmx?.session else {
            return []
        }

        return processes.arguments.keys.sorted().compactMap { pid in
            guard let device = processes.all[pid]?.device, Self.attaches(processes.arguments[pid], to: session) else {
                return nil
            }

            return processes.seat(of: pid, own: device).map { Place($0) }
        }
    }

    func unanswered(_: Board.Window.Where) -> [Unanswered] {
        []
    }

    func needsProcesses(_ where: Board.Window.Where) -> Bool {
        isIn(`where`)
    }

    /// Whether a command line attaches to the session: `zmx attach <session>`, by any path to zmx, and nothing after, a
    /// client's; or, `running`, any command after, as its server's.
    static func attaches(_ arguments: [String]?, to session: String, running: Bool = false) -> Bool {
        guard let arguments, arguments.count == 3 || running && arguments.count > 3, let zmx = arguments.first else {
            return false
        }

        return (zmx == "zmx" || zmx.hasSuffix("/zmx")) && arguments[1] == "attach" && arguments[2] == session
    }
}
