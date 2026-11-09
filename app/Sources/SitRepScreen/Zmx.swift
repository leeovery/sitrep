/// zmx's multiplexer adapter. A zmx session is one terminal, shown whole by every client attached to it, so there is no
/// window or pane to select. zmx 1.0.1 lists no session's clients, so they are read from the process table: each
/// process of zmx's program, on a tty, whose command line is exactly `zmx attach <session>`, by any path to zmx, the
/// name compared whole. The session's own server is on no tty, under launchd (live, 9 November 2026), so it is no
/// client, and its command line is never read.
///
/// A client switched in place, `zmx attach B` typed inside an attach on A, keeps A's name in its command line, and so
/// reads as A's: a known limit, as Portal's own switch starts a fresh `zmx attach B`.
public struct ZmxAdapter: Multiplexer {
    public init() {}

    public func isIn(_ where: Where) -> Bool {
        `where`.zmx != nil
    }

    /// A process of zmx's program on a tty, which may be a client: only its command line tells whose.
    public func tellsBy(_ process: Proc) -> Bool {
        process.device != nil && process.program?.split(separator: "/").last == "zmx"
    }

    /// zmx asks nothing of its own: its clients, and so which apps show its windows, are told by the table alone.
    public func read(_: [Where]) async -> any Reading {
        ZmxReading()
    }
}

struct ZmxReading: Reading {
    func isIn(_ where: Where) -> Bool {
        `where`.zmx != nil
    }

    /// zmx cannot tell its session's pty without a further program.
    func isOnItsPty(_: Where) -> Bool? {
        nil
    }

    /// Each client of the window's zmx session on a tty that a jump can reach, by its process's id, on the device of
    /// its terminal's own pty.
    func places(_ where: Where, _ processes: Processes) -> [Place] {
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

    func unanswered(_: Where) -> [Unanswered] {
        []
    }

    func needsProcesses(_ where: Where) -> Bool {
        isIn(`where`)
    }

    /// Whether a command line attaches to the session as a client: `zmx attach <session>`, by any path to zmx, and
    /// nothing after.
    static func attaches(_ arguments: [String]?, to session: String) -> Bool {
        guard let arguments, arguments.count == 3, let zmx = arguments.first else {
            return false
        }

        return (zmx == "zmx" || zmx.hasSuffix("/zmx")) && arguments[1] == "attach" && arguments[2] == session
    }
}
