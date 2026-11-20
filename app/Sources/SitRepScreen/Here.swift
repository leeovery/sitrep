import Darwin
import SitRepCore

/// Whether a session is here (DESIGN, stage 8, "Here"): a window holding it on the board, and a terminal on this Mac
/// that SitRep can take Lee to showing it; not here; or unknown, what was asked giving no answer, which is never taken
/// for not here. A session's `Sighting` tells it: here where `mac` is among its viewers.
public enum Here: Sendable, Equatable {
    case here
    case notHere
    case unknown([Unanswered])
}

/// One read of here, for every session asked of: each session's sighting; and the viewers of each tty inside a
/// multiplexer session, by its device, of those with any, for the board in a terminal to find its own; nil where the
/// table gave no answer.
public struct HereRead: Sendable, Equatable {
    public let sessions: [String: Sighting]
    public let ttys: [String: Set<Viewer>]?

    public init(sessions: [String: Sighting], ttys: [String: Set<Viewer>]?) {
        self.sessions = sessions
        self.ttys = ttys
    }
}

/// Reads whether sessions are here, by a read of its own beside the jump's (`ScreenReader`), which it leaves as it is,
/// and who views each (`Viewer`). The kernel's table is read once for every window, and each multiplexer for the
/// windows in it, tmux asked only for the sockets they run under; nothing is asked of a terminal app. A window in a
/// multiplexer is viewed by every client of its session, a tmux pane counting a client where a select would show it, as
/// the jump finds one; a window in none, by the processes on its device, by the same step. A client seated in a
/// terminal app (`Processes.seat`) is this Mac's; one under an SSH login, the device its address names. A remote login's
/// processes are seated in none (`seenFromHere`), and the heartbeat's `$TERM_PROGRAM`, which an ssh session may carry,
/// is never read.
public struct HereReader: Sendable {
    let multiplexers: [any Multiplexer]
    let table: any ProcessTable

    /// Every multiplexer a window may run in, tmux first, beside the process table.
    public init(tmux: any TmuxProgram, table: any ProcessTable = KernelProcesses()) {
        self.init(multiplexers: [TmuxAdapter(tmux), ZmxAdapter()], table: table)
    }

    init(multiplexers: [any Multiplexer], table: any ProcessTable) {
        self.multiplexers = multiplexers
        self.table = table
    }

    /// Who views each session, by the windows a jump tries for it, all read at once; and each multiplexer tty's.
    public func read(_ sessions: [String: [Board.Window.Where]]) async -> HereRead {
        let sight = await look(sessions.values.flatMap(\.self))

        return HereRead(sessions: sessions.mapValues(sight.sighting), ttys: sight.ttys)
    }

    /// Whether the session the windows hold is here; never, with none, as a session no window holds is away.
    func read(_ windows: [Board.Window.Where]) async -> Here {
        guard !windows.isEmpty else {
            return .notHere
        }

        return await look(windows).sighting(windows).here
    }

    /// The table, with the command lines the multiplexers tell their clients and their sessions' ttys by, beside what
    /// each multiplexer read for the windows in it.
    private func look(_ windows: [Board.Window.Where]) async -> Sight {
        async let processes = table.read { process in
            multiplexers.contains { $0.tellsBy(process) || $0.tellsTtysBy(process) }
        }
        let readings = await withTaskGroup(of: (Int, any Reading).self) { group in
            for (order, multiplexer) in multiplexers.enumerated() {
                group.addTask { (order, await multiplexer.read(windows.filter(multiplexer.isIn))) }
            }

            return await group.reduce(into: []) { $0.append($1) }.sorted { $0.0 < $1.0 }.map(\.1)
        }

        return await Sight(Screen(readings: readings, processes: processes?.seenFromHere), windows, table)
    }
}

/// What one read saw: the screen as the multiplexers and the table give it; the clients showing each window, and each
/// multiplexer tty; and each one's viewer, nil where the table gave no answer.
private struct Sight {
    let screen: Screen
    private let clients: [Board.Window.Where: [Client]]
    private let ttyClients: [String: [Client]]
    private let viewing: Viewing?

    init(_ screen: Screen, _ windows: [Board.Window.Where], _ table: any ProcessTable) {
        let tops = screen.processes?.tops ?? [:]
        let ttyClients = screen.processes.map { processes in
            screen.readings.reduce(into: [:]) { ttys, reading in ttys.merge(reading.ttys(processes), uniquingKeysWith: +) }
        } ?? [:]
        let clients = Dictionary(windows.map { ($0, Self.clients(of: $0, screen, tops)) }) { first, _ in first }
        let all = Set(clients.values.joined()).union(ttyClients.values.joined())

        self.screen = screen
        self.clients = clients
        self.ttyClients = ttyClients
        viewing = screen.processes.map { Viewing($0, clients: all, table: table) }
    }

    /// A window in a multiplexer, by the clients of its session the innermost finds; one in none, by the processes on
    /// its device whose parent is on another or none, through one of which every process on it descends.
    private static func clients(
        of where: Board.Window.Where, _ screen: Screen, _ tops: [String: [pid_t]]
    ) -> [Client] {
        guard screen.readings.contains(where: { $0.isIn(`where`) }) else {
            return `where`.tty.map { device in tops[device, default: []].map { Client(pid: $0, device: device) } } ?? []
        }

        return screen.clients(of: `where`)
    }

    func sighting(_ windows: [Board.Window.Where]) -> Sighting {
        Sighting(windows.map(sighting(of:)))
    }

    /// The viewers of each multiplexer tty that has any.
    var ttys: [String: Set<Viewer>]? {
        viewing.map { viewing in ttyClients.mapValues(viewing.viewers).filter { !$0.value.isEmpty } }
    }

    /// A window's viewers, unknown where what its showing is told by gave no answer: in a multiplexer, what it asked,
    /// or the table where its clients need it; in none, the table, unless it says no device.
    private func sighting(of where: Board.Window.Where) -> Sighting {
        let viewers = viewing?.viewers(of: clients[`where`] ?? []) ?? []
        let isInOne = screen.readings.contains { $0.isIn(`where`) }
        let unanswered = isInOne
            ? screen.unanswered(for: [`where`])
            : `where`.tty != nil && screen.processes == nil ? [.processes] : []

        return Sighting(viewers, unanswered: unanswered)
    }
}

extension Processes {
    /// The table as this Mac's terminals show it: each remote login cut from its parent, so no ancestry walked through
    /// one reaches a terminal app, even an sshd started from a terminal's shell.
    var seenFromHere: Processes {
        Processes(all.mapValues { $0.isRemoteLogin ? $0.orphaned : $0 }, arguments: arguments)
    }

    /// The processes on each device whose parent is on another, or none: a terminal app showing the device is above
    /// them, as above any process on it, so they alone need be seated.
    var tops: [String: [pid_t]] {
        all.reduce(into: [:]) { tops, each in
            if let device = each.value.device, all[each.value.parent]?.device != device {
                tops[device, default: []].append(each.key)
            }
        }
    }
}

extension Proc {
    /// The programs of a remote login, under which a shell is reached from another device: the SSH logins; and mosh's.
    static let remoteLogins = sshLogins.union(["mosh-server"])
    /// Of those, the logins whose sessions carry the `SSH_CONNECTION` of the SSH login that reached them: OpenSSH's
    /// server, and its session's own process since OpenSSH 9.8; and `tsshd`, trzsz-ssh's server for its UDP mode,
    /// which an SSH login starts and which then runs apart, under launchd, as Lee's phone reaches this Mac through
    /// rootshell's tssh (live, 20 November 2026).
    static let sshLogins: Set<Substring> = ["sshd", "sshd-session", "tsshd"]

    var isRemoteLogin: Bool {
        programName.map(Self.remoteLogins.contains) ?? false
    }

    var isSSHLogin: Bool {
        programName.map(Self.sshLogins.contains) ?? false
    }

    /// Its program's file's name.
    private var programName: Substring? {
        program.map { program in program.lastIndex(of: "/").map { program[program.index(after: $0)...] } ?? program[...] }
    }

    /// The process with no parent.
    fileprivate var orphaned: Proc {
        Proc(parent: 0, device: device, program: program, isStopped: isStopped)
    }
}
