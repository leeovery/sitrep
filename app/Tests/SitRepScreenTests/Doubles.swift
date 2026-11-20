import Darwin
import os
import SitRepCore
@testable import SitRepScreen

let ghosttyProgram = "/Applications/Ghostty.app/Contents/MacOS/ghostty"
let terminalProgram = "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"
let codeHelper = "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper"
let zmxProgram = "/opt/homebrew/Cellar/zmx/1.0.1/bin/zmx"

/// SitRepCore's `Where`, named shortly for the tests.
typealias Where = Board.Window.Where

/// A process tree built in code, each process given the next id: launchd at 1, and what is added under it.
struct Tree: Sendable {
    private(set) var processes: [pid_t: Proc] = [1: Proc(parent: 0, program: "/sbin/launchd")]
    private(set) var arguments: [pid_t: [String]] = [:]
    /// The SSH client address in each process's environment, of those whose holds one.
    private(set) var addresses: [pid_t: String] = [:]
    /// The processes whose environment macOS hides from others, as it does its own programs'.
    private(set) var hidden: Set<pid_t> = []
    private var next: pid_t = 100

    /// A process under the parent, on the device given, running the program with the command line given; its
    /// environment naming the SSH client address given, which its children inherit unless given another, and hidden
    /// from others where it is macOS's own program.
    @discardableResult
    mutating func add(
        under parent: pid_t, _ program: String?, on device: String? = nil, arguments: [String]? = nil,
        isStopped: Bool = false, ssh address: String? = nil
    ) -> pid_t {
        let pid = next

        next += 1
        processes[pid] = Proc(parent: parent, device: device, program: program, isStopped: isStopped)
        arguments.map { self.arguments[pid] = $0 }
        addresses[pid] = address ?? addresses[parent]
        if program.map(Self.isMacOSs) == true {
            hidden.insert(pid)
        }

        return pid
    }

    /// Whether a program is macOS's own, in the system's folders.
    private static func isMacOSs(_ program: String) -> Bool {
        ["/bin/", "/sbin/", "/usr/bin/", "/usr/sbin/", "/usr/libexec/"].contains { program.hasPrefix($0) }
    }

    /// An app, or a server, launchd started: on no tty.
    mutating func app(_ program: String) -> pid_t {
        add(under: 1, program)
    }

    /// A terminal window of the app on its own pty: `zsh < login < the app`, the shell's id.
    mutating func window(of app: pid_t, on device: String) -> pid_t {
        add(under: add(under: app, "/usr/bin/login", on: device), "/bin/zsh", on: device)
    }

    /// A shell on the device under a program on no app: `zsh < mosh-server` for Lee's phone, `zsh < sshd-session <
    /// sshd` for a Ghostty on another Mac; its environment naming the SSH client address given, as sshd sets it.
    mutating func shell(under programs: [String], on device: String, ssh address: String? = nil) -> pid_t {
        add(under: programs.reduce(1) { add(under: $0, $1) }, "/bin/zsh", on: device, ssh: address)
    }

    /// A tmux client under the shell, on the device.
    mutating func tmux(under shell: pid_t, on device: String?) -> pid_t {
        add(under: shell, "/opt/homebrew/bin/tmux", on: device)
    }

    /// A relaying pty's program under the shell, its child on the relay's own pty: Portal, `script`.
    mutating func relay(under shell: pid_t, on device: String, _ program: String = "/opt/homebrew/bin/portal") -> pid_t {
        add(under: shell, program, on: device)
    }

    /// A zmx client of the session under the process, run as `zmx attach <session>` by the path given.
    @discardableResult
    mutating func zmx(_ session: String, under parent: pid_t, on device: String?, by zmx: String = "/opt/homebrew/bin/zmx")
        -> pid_t
    {
        add(under: parent, zmxProgram, on: device, arguments: [zmx, "attach", session])
    }
}

/// The process table holding a tree, or giving no answer, which keeps what it was asked.
final class FakeTable: ProcessTable {
    private let tree: Tree?
    private let asked = OSAllocatedUnfairLock(
        initialState: (looks: 0, arguments: [pid_t](), addressReaders: 0, addresses: [pid_t]())
    )

    init(_ tree: Tree?) {
        self.tree = tree
    }

    /// How many times the whole table was read.
    var looks: Int { asked.withLock(\.looks) }
    /// Whose command lines were read.
    var argumentsRead: [pid_t] { asked.withLock(\.arguments).sorted() }
    /// How many readers of SSH client addresses were made.
    var addressReaders: Int { asked.withLock(\.addressReaders) }
    /// Whose SSH client addresses were read, in turn.
    var addressesRead: [pid_t] { asked.withLock(\.addresses) }

    func sshAddressReader() -> (pid_t) -> String? {
        asked.withLock { $0.addressReaders += 1 }

        return { [tree, asked] pid in
            asked.withLock { $0.addresses.append(pid) }

            return tree.flatMap { $0.hidden.contains(pid) ? nil : $0.addresses[pid] }
        }
    }

    func read(arguments wanted: (Proc) -> Bool) -> Processes? {
        asked.withLock { $0.looks += 1 }

        guard let tree else {
            return nil
        }

        let arguments = tree.arguments.filter { pid, _ in tree.processes[pid].map(wanted) == true }

        asked.withLock { $0.arguments += arguments.keys }

        return Processes(tree.processes, arguments: arguments)
    }
}

/// A pane as tmux lists it: its id, its tmux window, a tmux session holding the window, and its device.
struct FakePane {
    let pane: String
    let window: String
    let session: String
    var device = ""
}

/// A client as tmux lists it: its device, its process, the tmux window it shows and the tmux session it is attached
/// to, unless given the one named for its window, as each of Lee's tmux sessions had one window.
struct FakeClient {
    let device: String
    let pid: pid_t
    let window: String
    var session: String?
}

/// A tmux server: its panes and its clients.
struct FakeServer {
    var panes: [FakePane] = []
    var clients: [FakeClient] = []
}

/// tmux, its servers by socket, answering as the real one does: a socket no server is on with an error; or, `silent`,
/// giving no answer at all, as tmux too slow does, for every socket or those given; or, `failing`, exiting with the
/// error given for its socket; or `missing`, not found on the PATH. A select it answers as `select` says, nil for no
/// answer. It keeps every run it was asked for.
final class FakeTmux: TmuxProgram {
    private let servers: [String: FakeServer]
    private let isMissing: Bool
    private let isSilent: Bool
    private let silentSockets: Set<String>
    private let failing: [String: String]
    private let selected: Ran?
    private let asked = OSAllocatedUnfairLock(initialState: (runs: [[String]](), words: [[String]](), selects: [[String]]()))

    init(
        _ servers: [String: FakeServer] = [:], missing: Bool = false, silent: Bool = false,
        silentOn sockets: Set<String> = [], failing: [String: String] = [:],
        select: Ran? = Ran(status: 0, stdout: "", stderr: "")
    ) {
        self.servers = servers
        isMissing = missing
        isSilent = silent
        silentSockets = sockets
        self.failing = failing
        selected = select
    }

    /// Each run, its socket then its first word.
    var runs: [[String]] { asked.withLock(\.runs) }
    /// Each run's whole words, in turn.
    var words: [[String]] { asked.withLock(\.words) }
    /// Each select, its socket then its words after `select-window`.
    var selects: [[String]] { asked.withLock(\.selects) }

    static let unanswered = TmuxUnanswered.unanswered(.timedOut(2))

    func run(on socket: String, _ words: [String]) async throws -> Ran {
        asked.withLock { asked in
            asked.runs.append([socket, words[0]])
            asked.words.append(words)
            if words[0] == "select-window" {
                asked.selects.append([socket] + words.dropFirst())
            }
        }

        guard !isMissing else {
            throw TmuxUnanswered.notFound
        }
        guard !isSilent, !silentSockets.contains(socket) else {
            throw Self.unanswered
        }
        if let said = failing[socket] {
            return Ran(status: 1, stdout: "", stderr: said + "\n")
        }

        if words[0] == "select-window" {
            guard let selected else {
                throw Self.unanswered
            }

            return selected
        }

        guard let server = servers[socket] else {
            return Ran(status: 1, stdout: "", stderr: "no server running on \(socket)\n")
        }

        let lines = switch words[0] {
        case "list-panes":
            server.panes.map { [$0.pane, $0.window, $0.session, $0.device] }
        default:
            server.clients.map { [$0.device, String($0.pid), $0.window, $0.session ?? "$" + $0.window.dropFirst()] }
        }

        return Ran(status: 0, stdout: lines.map { $0.joined(separator: "\t") + "\n" }.joined(), stderr: "")
    }
}

/// A Mac built in code: Ghostty and Terminal running, and the clients each test adds, in their windows or elsewhere.
struct Mac {
    var tree = Tree()
    let ghostty: pid_t
    let terminal: pid_t

    init() {
        ghostty = tree.app(ghosttyProgram)
        terminal = tree.app(terminalProgram)
    }

    /// A tmux client in a Ghostty window on the device: `tmux < zsh < login < ghostty`; on no device of its own, as a
    /// control-mode client over pipes, where `own` is empty.
    mutating func inGhostty(_ device: String, own: String? = nil) -> pid_t {
        tree.tmux(under: tree.window(of: ghostty, on: device), on: own == "" ? nil : device)
    }

    /// A tmux client in a Terminal window on the device.
    mutating func inTerminal(_ device: String) -> pid_t {
        tree.tmux(under: tree.window(of: terminal, on: device), on: device)
    }

    /// A tmux client on Lee's phone: `tmux < zsh < mosh-server`.
    mutating func onPhone(_ device: String) -> pid_t {
        tree.tmux(under: tree.shell(under: ["/opt/homebrew/bin/mosh-server"], on: device), on: device)
    }

    /// A tmux client of a Ghostty on another Mac, over ssh: `tmux < zsh < sshd-session < sshd`.
    mutating func overSsh(_ device: String, from address: String = Mac.phone) -> pid_t {
        tree.tmux(under: tree.shell(under: Mac.sshd, on: device, ssh: address), on: device)
    }

    /// OpenSSH's server and its session's process, as a login over ssh runs under them.
    static let sshd = ["/usr/sbin/sshd", "/usr/libexec/sshd-session"]

    /// The SSH client addresses of Lee's phone and iPad, documentation's own (RFC 5737).
    static let phone = "192.0.2.7"
    static let iPad = "198.51.100.4"

    /// A zmx client of the session attached over ssh from the address given, straight from the login's shell: `zmx <
    /// zsh < sshd-session < sshd`.
    @discardableResult
    mutating func zmxOverSsh(_ session: String, on device: String, from address: String = Mac.phone) -> pid_t {
        tree.zmx(session, under: tree.shell(under: Mac.sshd, on: device, ssh: address), on: device)
    }

    /// trzsz-ssh's UDP server, which the phone's tssh starts through an SSH login for each tab.
    static let tsshd = "/opt/homebrew/Cellar/tsshd/0.1.10/bin/tsshd"

    /// A zmx client of the session Portal attached in a tab of Lee's phone, through tssh: `zmx < portal < zsh <
    /// tsshd`, tsshd run apart under launchd with its SSH login's environment, the client on Portal's relaying pty
    /// (live, 20 November 2026).
    @discardableResult
    mutating func throughTssh(_ session: String, relay: String, tab device: String, from address: String = Mac.phone)
        -> pid_t
    {
        let shell = tree.add(under: tree.add(under: 1, Mac.tsshd, ssh: address), "/bin/zsh", on: device)

        return tree.zmx(session, under: tree.relay(under: shell, on: device), on: relay)
    }

    /// A zmx client of the session Portal attached in a Ghostty window on the device, the client on Portal's own
    /// relaying pty: `zmx < portal < zsh < login < ghostty` (live, 9 November 2026).
    @discardableResult
    mutating func throughPortal(_ session: String, relay: String, window device: String) -> pid_t {
        tree.zmx(session, under: tree.relay(under: tree.window(of: ghostty, on: device), on: device), on: relay)
    }

    /// A zmx client of the session attached straight from a Terminal window's shell, zmx run by its name alone; on no
    /// device of its own, over pipes, where `isPiped`.
    @discardableResult
    mutating func zmxInTerminal(_ session: String, on device: String, isPiped: Bool = false) -> pid_t {
        tree.zmx(session, under: tree.window(of: terminal, on: device), on: isPiped ? nil : device, by: "zmx")
    }

    /// A zmx session's server: on no tty, under launchd, its command line a client's, then any command it runs; and the
    /// shell it started on the session's own tty, where one is given.
    @discardableResult
    mutating func zmxServer(_ session: String, running command: [String] = [], tty: String? = nil) -> pid_t {
        let server = tree.add(under: 1, zmxProgram, arguments: ["zmx", "attach", session] + command)

        tty.map { _ = tree.add(under: server, "/bin/zsh", on: $0) }
        return server
    }

    /// Claude Code on the device, by its program's path: Claude Code's own installer's, named by its version, unless
    /// another is given; running, or stopped, as Ctrl-Z leaves it.
    @discardableResult
    mutating func claude(
        on device: String, program: String = "/Users/me/.local/share/claude/versions/2.1.322", isStopped: Bool = false
    ) -> pid_t {
        tree.add(under: 1, program, on: device, isStopped: isStopped)
    }
}
