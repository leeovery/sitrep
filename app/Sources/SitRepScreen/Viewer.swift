import Darwin

/// Where a client showing a session is looked at from (DESIGN, "The board in a terminal", 20 November 2026): this Mac's
/// screen, or a device reached over SSH, by its address, so every terminal one phone opens counts as that phone.
public enum Viewer: Sendable, Hashable {
    case mac
    case ssh(String)

    /// As `here.json` writes it: `mac`, or `ssh:` and the address.
    public var text: String {
        switch self {
        case .mac: "mac"
        case let .ssh(address): "ssh:\(address)"
        }
    }
}

/// Who a read of here saw view a session, or that it could not tell, which is never taken for nobody.
public enum Sighting: Sendable, Equatable {
    case seen(Set<Viewer>)
    case unknown([Unanswered])

    /// Seen by the viewers given, unless what was asked gave no answer, each thing unanswered once; this Mac's screen
    /// among them wins, as today's here does over unknown.
    init(_ viewers: Set<Viewer>, unanswered: [Unanswered]) {
        var seen: Set<Unanswered> = []

        self = viewers.contains(.mac) || unanswered.isEmpty
            ? .seen(viewers)
            : .unknown(unanswered.filter { seen.insert($0).inserted })
    }

    /// A session's, from its windows': every viewer seen of any; unknown only where none is this Mac's screen and any
    /// window is unknown.
    init(_ windows: [Sighting]) {
        self.init(
            windows.reduce(into: []) { viewers, window in viewers.formUnion(window.viewers) },
            unanswered: windows.flatMap(\.unanswered)
        )
    }

    /// Whether this Mac's screen shows it, as the notch and the jump go by: here where `mac` is among its viewers.
    public var here: Here {
        switch self {
        case let .seen(viewers): viewers.contains(.mac) ? .here : .notHere
        case let .unknown(unanswered): .unknown(unanswered)
        }
    }

    private var viewers: Set<Viewer> {
        if case let .seen(viewers) = self { viewers } else { [] }
    }

    private var unanswered: [Unanswered] {
        if case let .unknown(unanswered) = self { unanswered } else { [] }
    }
}

/// What the read of here last settled (`HereWatch`), as `here.json` holds it: each held session's viewers, of those
/// read; and each tty inside a multiplexer session, by its device, with that session's viewers, of those with any.
public struct Sightings: Sendable, Equatable {
    public var sessions: [String: Set<Viewer>]
    public var ttys: [String: Set<Viewer>]

    public init(sessions: [String: Set<Viewer>] = [:], ttys: [String: Set<Viewer>] = [:]) {
        self.sessions = sessions
        self.ttys = ttys
    }

    /// The sessions this Mac's screen doesn't show, which the notch dims: those read whose viewers hold no `mac`. One
    /// never read is here.
    public var notHere: Set<String> {
        Set(sessions.filter { !$0.value.contains(.mac) }.keys)
    }
}

/// Each client's viewer, for one read: `mac` where it is seated in a terminal app here (`Processes.seat`); `ssh:` and
/// its address where the nearest remote login above it is an SSH login and its environment names the address; none for
/// any other, Lee's phone through mosh among them.
///
/// macOS hides the environment of its own programs from other processes (live, 20 November 2026): a login shell's,
/// `/bin/zsh`, which tops a terminal holding Claude in no multiplexer. So a client whose own environment gives no
/// address takes the first another process on its tty gives: every process on a login's tty is that login's. Those are
/// read one at a time, in order of process id, and none after the first that gives one. No other environment is read:
/// only those of the clients an SSH login reached, and of those processes.
struct Viewing {
    private let viewers: [Client: Viewer]

    /// Each client's viewer, its address read through the table given; with none, as at a click, which asks only
    /// whether this Mac's screen shows a session, no environment is read, and a client not seated here has no viewer.
    init(_ processes: Processes, clients: Set<Client>, addresses table: (any ProcessTable)?) {
        var viewers: [Client: Viewer] = [:]
        var overSSH: [Client] = []

        for client in clients {
            if processes.seat(of: client.pid, own: client.device) != nil {
                viewers[client] = .mac
            } else if table != nil, processes.isReachedOverSSH(client.pid) {
                overSSH.append(client)
            }
        }

        if let table, !overSSH.isEmpty {
            let addresses = Self.addresses(of: overSSH, processes, table.sshAddressReader())

            for client in overSSH {
                viewers[client] = addresses[client].map(Viewer.ssh)
            }
        }

        self.viewers = viewers
    }

    /// Each client's address: its own environment's; else the first another process on its tty gives.
    private static func addresses(
        of clients: [Client], _ processes: Processes, _ address: (pid_t) -> String?
    ) -> [Client: String] {
        let own = clients.reduce(into: [Client: String]()) { own, client in own[client] = address(client.pid) }
        let asked = Set(clients.map(\.pid))
        let ttys = Set(clients.filter { own[$0] == nil }.compactMap(\.device))
        let onTtys: [String: [pid_t]] = processes.all.reduce(into: [:]) { onTtys, each in
            if let device = each.value.device, ttys.contains(device), !asked.contains(each.key) {
                onTtys[device, default: []].append(each.key)
            }
        }
        let firstOnTty = onTtys.compactMapValues { pids in Self.first(of: pids.sorted(), address) }

        return clients.reduce(into: [:]) { addresses, client in
            addresses[client] = own[client] ?? client.device.flatMap { firstOnTty[$0] }
        }
    }

    /// The first address the processes give, in turn, none read after it.
    private static func first(of pids: [pid_t], _ address: (pid_t) -> String?) -> String? {
        for pid in pids {
            if let found = address(pid) {
                return found
            }
        }

        return nil
    }

    func viewers(of clients: [Client]) -> Set<Viewer> {
        Set(clients.compactMap { viewers[$0] })
    }
}

extension Processes {
    /// Whether the nearest remote login among a process's ancestors is an SSH login (`Proc.sshLogins`). Each ancestor
    /// is looked at once, as a table read while ids are reused can loop.
    func isReachedOverSSH(_ pid: pid_t) -> Bool {
        var seen: Set<pid_t> = []
        var process = all[pid]

        while let below = process, seen.insert(below.parent).inserted {
            process = all[below.parent]

            if let login = process, login.isRemoteLogin {
                return login.isSSHLogin
            }
        }

        return false
    }
}
