import Darwin
import SitRepCore

/// Whether a session is here (DESIGN, stage 8, "Here"): a window holding it on the board, and a terminal on this Mac
/// that SitRep can take Lee to showing it; not here; or unknown, what was asked giving no answer, which is never taken
/// for not here.
public enum Here: Sendable, Equatable {
    case here
    case notHere
    case unknown([Unanswered])

    /// A session's, from its windows': here where any is; else unknown where any is, each thing unanswered once; else
    /// not here, as a session no window holds is.
    init(_ windows: [Here]) {
        guard !windows.contains(.here) else {
            self = .here
            return
        }

        var seen: Set<Unanswered> = []
        let unanswered = windows.flatMap(\.unanswered)

        self = unanswered.isEmpty ? .notHere : .unknown(unanswered.filter { seen.insert($0).inserted })
    }

    private var unanswered: [Unanswered] {
        if case let .unknown(unanswered) = self { unanswered } else { [] }
    }
}

/// Reads whether sessions are here, by a read of its own beside the jump's (`ScreenReader`), which it leaves as it is.
/// The kernel's table is read once for every window, and each multiplexer for the windows in it, tmux asked only for
/// the sockets they run under; nothing is asked of a terminal app. A window in a multiplexer is here where a client of
/// its session is seated in a terminal app (`Processes.seat`), a tmux pane counting where a select would show it, as
/// the jump finds one; a window in none, where a process on its device is, by the same step. A remote login's
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

    /// Whether each session is here, by the windows a jump tries for it, all read at once.
    public func read(_ sessions: [String: [Board.Window.Where]]) async -> [String: Here] {
        let sight = await look(sessions.values.flatMap(\.self))

        return sessions.mapValues(sight.here)
    }

    /// Whether the session the windows hold is here; never, with none, as a session no window holds is away.
    func read(_ windows: [Board.Window.Where]) async -> Here {
        guard !windows.isEmpty else {
            return .notHere
        }

        return await look(windows).here(windows)
    }

    /// The table, with the command lines the multiplexers tell their clients by, beside what each multiplexer read for
    /// the windows in it.
    private func look(_ windows: [Board.Window.Where]) async -> Sight {
        async let processes = table.read { process in multiplexers.contains { $0.tellsBy(process) } }
        let readings = await withTaskGroup(of: (Int, any Reading).self) { group in
            for (order, multiplexer) in multiplexers.enumerated() {
                group.addTask { (order, await multiplexer.read(windows.filter(multiplexer.isIn))) }
            }

            return await group.reduce(into: []) { $0.append($1) }.sorted { $0.0 < $1.0 }.map(\.1)
        }

        return await Sight(screen: Screen(readings: readings, processes: processes?.seenFromHere))
    }
}

/// What one read saw: the screen as the multiplexers and the table give it, and the table's processes on each device
/// whose parent is on another or none, through one of which every process on it descends.
private struct Sight {
    let screen: Screen
    let tops: [String: [pid_t]]

    init(screen: Screen) {
        self.screen = screen
        tops = screen.processes?.tops ?? [:]
    }

    func here(_ windows: [Board.Window.Where]) -> Here {
        Here(windows.map(here(of:)))
    }

    /// A window in a multiplexer, by what the jump would reach; one in none, by its device in the table.
    private func here(of where: Board.Window.Where) -> Here {
        guard screen.readings.contains(where: { $0.isIn(`where`) }) else {
            return outside(`where`)
        }

        return switch screen.reach(of: [`where`]) {
        case .onScreen: .here
        case .offScreen: .notHere
        case let .unknown(unanswered): .unknown(unanswered)
        }
    }

    private func outside(_ where: Board.Window.Where) -> Here {
        guard let device = `where`.tty else {
            return .notHere
        }
        guard let processes = screen.processes else {
            return .unknown([.processes])
        }

        return tops[device, default: []].contains { processes.seat(of: $0, own: device) != nil } ? .here : .notHere
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
    /// The programs of a remote login, under which a shell is reached from another device: OpenSSH's server, and its
    /// session's own process since OpenSSH 9.8; and mosh's, as Lee's phone reaches this Mac.
    static let remoteLogins: Set<Substring> = ["sshd", "sshd-session", "mosh-server"]

    var isRemoteLogin: Bool {
        guard let program else {
            return false
        }

        let name = program.lastIndex(of: "/").map { program[program.index(after: $0)...] } ?? program[...]

        return Self.remoteLogins.contains(name)
    }

    /// The process with no parent.
    fileprivate var orphaned: Proc {
        Proc(parent: 0, device: device, program: program, isStopped: isStopped)
    }
}
