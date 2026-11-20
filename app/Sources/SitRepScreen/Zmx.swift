import SitRepCore

/// zmx's multiplexer adapter. A zmx session is one terminal, shown whole by every client attached to it, so there is no
/// window or pane to select. zmx 1.0.1 lists no session's clients, so they are read from the process table: each
/// process of zmx's program, on a tty, whose command line is exactly `zmx attach <session>`, by any path to zmx, the
/// name compared whole, in order of process id: the oldest client first, until ids wrap round. The session's own
/// server is on no tty, under launchd (live, 9 November 2026), so it is no client. The jump never reads its command
/// line; the read of here does, for the tty of the shell it started, the session's own (`ttys`).
///
/// Only a process whose program's file is named `zmx` has its command line read, which keeps the reads to a few a look;
/// the CLI read every process's from `ps`. So a zmx installed under another name reads off screen.
///
/// A client switched in place, `zmx attach B` typed inside an attach on A, keeps A's name in its command line, and so
/// reads as A's: a known limit, as Portal's own switch starts a fresh `zmx attach B`.
public struct ZmxAdapter: Multiplexer {
    public init() {}

    public func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.zmx != nil
    }

    /// A process of zmx's program on a tty, which may be a client: only its command line tells whose.
    public func tellsBy(_ process: Proc) -> Bool {
        process.device != nil && Self.isZmx(process)
    }

    /// A process of zmx's program on no tty, which may be a session's server: only its command line tells whose.
    public func tellsTtysBy(_ process: Proc) -> Bool {
        process.device == nil && Self.isZmx(process)
    }

    private static func isZmx(_ process: Proc) -> Bool {
        process.program?.split(separator: "/").last == "zmx"
    }

    /// zmx asks nothing of its own: its clients, and so which apps show its windows, are told by the table alone.
    public func read(_: [Board.Window.Where]) async -> any Reading {
        ZmxReading()
    }
}

struct ZmxReading: Reading {
    func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.zmx != nil
    }

    /// zmx cannot tell its session's pty without a further program.
    func isOnItsPty(_: Board.Window.Where) -> Bool? {
        nil
    }

    /// Each client of the window's zmx session that a jump can reach, on the device of its terminal's own pty.
    func places(_ where: Board.Window.Where, _ processes: Processes) -> [Place] {
        clients(`where`, processes).compactMap { client in
            processes.seat(of: client.pid, own: client.device).map { Place($0) }
        }
    }

    /// Each client of the window's zmx session on a tty, by its process's id.
    func clients(_ where: Board.Window.Where, _ processes: Processes) -> [Client] {
        `where`.zmx.map { Self.clients(of: $0.session, processes) } ?? []
    }

    /// The tty of each process a zmx session's server started, its session's own, and the clients of that session.
    /// A server is a process of zmx's program on no tty whose command line starts as a client's, `zmx attach
    /// <session>`, any command it runs after.
    func ttys(_ processes: Processes) -> [String: [Client]] {
        let servers = processes.arguments.compactMapValues(Self.served).filter { processes.all[$0.key]?.device == nil }

        guard !servers.isEmpty else {
            return [:]
        }

        return processes.all.values.reduce(into: [:]) { ttys, process in
            if let session = servers[process.parent], let device = process.device {
                ttys[device] = Self.clients(of: session, processes)
            }
        }
    }

    /// Each process of zmx's program on a tty attached to the session as a client, in order of process id.
    private static func clients(of session: String, _ processes: Processes) -> [Client] {
        processes.arguments.keys.sorted().compactMap { pid in
            guard let device = processes.all[pid]?.device, attaches(processes.arguments[pid], to: session) else {
                return nil
            }

            return Client(pid: pid, device: device)
        }
    }

    func unanswered(_: Board.Window.Where) -> [Unanswered] {
        []
    }

    func needsProcesses(_ where: Board.Window.Where) -> Bool {
        isIn(`where`)
    }

    /// Whether a command line attaches to the session as a client: `zmx attach <session>`, by any path to zmx, and
    /// nothing after.
    static func attaches(_ arguments: [String]?, to session: String) -> Bool {
        guard let arguments, arguments.count == 3, isZmx(arguments[0]) else {
            return false
        }

        return arguments[1] == "attach" && arguments[2] == session
    }

    /// The session a command line attaches to, a command after it allowed, as a server's runs it.
    private static func served(_ arguments: [String]) -> String? {
        arguments.count >= 3 && isZmx(arguments[0]) && arguments[1] == "attach" ? arguments[2] : nil
    }

    /// zmx's program, by any path to it.
    private static func isZmx(_ program: String) -> Bool {
        program == "zmx" || program.hasSuffix("/zmx")
    }
}
