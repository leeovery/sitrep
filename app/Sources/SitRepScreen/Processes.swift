import Darwin

/// A process, as the kernel gives it: its parent, the terminal it is on, and its program.
public struct Proc: Sendable, Equatable {
    public let parent: pid_t
    /// The pty it is on, `/dev/ttys032`; nil for none, or any device but a pty.
    public let device: String?
    /// Its program's path, exactly; nil where it could not be read, as for a process just gone.
    public let program: String?

    public init(parent: pid_t, device: String? = nil, program: String? = nil) {
        self.parent = parent
        self.device = device
        self.program = program
    }
}

/// Every process of this Mac: one look at the kernel's table, and a process's command line read only where needed.
public protocol ProcessTable: Sendable {
    /// Every process, by its id; nil where the kernel gave none.
    func processes() -> [pid_t: Proc]?
    /// A process's command line, its program first as it was started; nil where it cannot be read.
    func arguments(of pid: pid_t) -> [String]?
}

/// Every process, by its id, and the command line of each a multiplexer tells its clients by.
public struct Processes: Sendable {
    public let all: [pid_t: Proc]
    let arguments: [pid_t: [String]]

    public init(_ all: [pid_t: Proc], arguments: [pid_t: [String]] = [:]) {
        self.all = all
        self.arguments = arguments
    }

    /// One look at the table, and the command line of each process wanted; nil where the table gave none.
    static func read(_ table: any ProcessTable, arguments wanted: (Proc) -> Bool) -> Processes? {
        table.processes().map { all in
            let arguments = all.compactMap { pid, process in
                wanted(process) ? table.arguments(of: pid).map { (pid, $0) } : nil
            }

            return Processes(all, arguments: Dictionary(uniqueKeysWithValues: arguments))
        }
    }

    /// The nearest ancestor of a process that is a terminal app, and that app's own child among them, the process
    /// itself or one above it. A table read as processes come and go, their ids reused, can loop, so each ancestor is
    /// looked at once.
    private func appAbove(_ pid: pid_t) -> (app: TerminalApp, child: Proc)? {
        var seen: Set<pid_t> = []
        var child = all[pid]

        while let below = child, seen.insert(below.parent).inserted {
            let parent = all[below.parent]

            if let app = parent?.program.flatMap(TerminalApp.init(path:)) {
                return (app, below)
            }

            child = parent
        }

        return nil
    }

    /// Where a multiplexer's client can be brought forward: in the nearest terminal app among its ancestors, on the
    /// device of the app's own child, the terminal's pty, however many relaying ptys sit between (Portal's,
    /// `script`'s); where that child is on none, on the client's own device. A client on no tty of its own, as a tmux
    /// control-mode client over pipes, is on no device: it is no window a driver could find. Nil for a client in no
    /// app, as Lee's phone through mosh-server or a Ghostty on another Mac over ssh, or in a driver's app on no device.
    public func seat(of pid: pid_t, own: String?) -> Seat? {
        guard let above = appAbove(pid) else {
            return nil
        }

        let device = isDevice(own) ? above.child.device ?? own : nil

        return above.app.reaches(device) ? Seat(app: above.app, device: device) : nil
    }
}

/// Where a jump can bring a client forward: the terminal app it is in, and the device of its window there, which only
/// an app with no driver may lack.
public struct Seat: Sendable, Hashable {
    public let app: TerminalApp
    public let device: String?

    public init(app: TerminalApp, device: String?) {
        self.app = app
        self.device = device
    }
}
