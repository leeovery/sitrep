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
    private var next: pid_t = 100

    /// A process under the parent, on the device given, running the program with the command line given.
    @discardableResult
    mutating func add(under parent: pid_t, _ program: String?, on device: String? = nil, arguments: [String]? = nil)
        -> pid_t
    {
        let pid = next

        next += 1
        processes[pid] = Proc(parent: parent, device: device, program: program)
        arguments.map { self.arguments[pid] = $0 }

        return pid
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
    /// sshd` for a Ghostty on another Mac.
    mutating func shell(under programs: [String], on device: String) -> pid_t {
        add(under: programs.reduce(1) { add(under: $0, $1) }, "/bin/zsh", on: device)
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
    private let asked = OSAllocatedUnfairLock(initialState: (looks: 0, arguments: [pid_t]()))

    init(_ tree: Tree?) {
        self.tree = tree
    }

    /// How many times the whole table was read.
    var looks: Int { asked.withLock(\.looks) }
    /// Whose command lines were read.
    var argumentsRead: [pid_t] { asked.withLock(\.arguments).sorted() }

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

/// A tmux server: its panes, its clients, and its tmux sessions' names by their ids, a session not named there named
/// by its id.
struct FakeServer {
    var panes: [FakePane] = []
    var clients: [FakeClient] = []
    var names: [String: String] = [:]

    /// `display-message -p -t <pane> '#{session_name}'`: the name of the first tmux session holding the pane, or
    /// tmux's error for a pane it has not.
    func sessionName(holding pane: String) -> Ran {
        guard let session = panes.first(where: { $0.pane == pane })?.session else {
            return Ran(status: 1, stdout: "", stderr: "can't find pane: \(pane)\n")
        }

        return Ran(status: 0, stdout: (names[session] ?? session) + "\n", stderr: "")
    }
}

/// tmux, its servers by socket, answering as the real one does: a socket no server is on with an error; or, `silent`,
/// giving no answer at all, as tmux missing or too slow does, for every socket or those given. A select it answers as
/// `select` says, nil for no answer. It keeps every run it was asked for.
final class FakeTmux: TmuxProgram {
    private let servers: [String: FakeServer]
    private let isSilent: Bool
    private let silentSockets: Set<String>
    private let selected: Ran?
    private let asked = OSAllocatedUnfairLock(initialState: (runs: [[String]](), words: [[String]](), selects: [[String]]()))

    init(
        _ servers: [String: FakeServer] = [:], silent: Bool = false, silentOn sockets: Set<String> = [],
        select: Ran? = Ran(status: 0, stdout: "", stderr: "")
    ) {
        self.servers = servers
        isSilent = silent
        silentSockets = sockets
        selected = select
    }

    /// Each run, its socket then its first word.
    var runs: [[String]] { asked.withLock(\.runs) }
    /// Each run's whole words, in turn.
    var words: [[String]] { asked.withLock(\.words) }
    /// Each select, its socket then its words after `select-window`.
    var selects: [[String]] { asked.withLock(\.selects) }

    func run(on socket: String, _ words: [String]) async -> Ran? {
        asked.withLock { asked in
            asked.runs.append([socket, words[0]])
            asked.words.append(words)
            if words[0] == "select-window" {
                asked.selects.append([socket] + words.dropFirst())
            }
        }

        guard !isSilent, !silentSockets.contains(socket) else {
            return nil
        }

        if words[0] == "select-window" {
            return selected
        }

        guard let server = servers[socket] else {
            return Ran(status: 1, stdout: "", stderr: "no server running on \(socket)\n")
        }

        if words[0] == "display-message" {
            return server.sessionName(holding: words[3])
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

/// zmx, listing the sessions given, one a line, as `zmx list --short` does, or answering as given, nil for no answer.
/// It keeps every run it was asked for.
final class FakeZmx: ZmxProgram {
    /// The sessions these tests' windows run in.
    static let lees = ["kit", "leeway", "agentic-workflows-v2 · leeway-build", "kit · restore-card"]

    private let answer: Ran?
    private let asked = OSAllocatedUnfairLock(initialState: [[String]]())

    init(listing sessions: [String] = lees) {
        answer = Ran(status: 0, stdout: sessions.map { $0 + "\n" }.joined(), stderr: "")
    }

    init(answering answer: Ran?) {
        self.answer = answer
    }

    var runs: [[String]] { asked.withLock { $0 } }

    func run(_ words: [String]) async -> Ran? {
        asked.withLock { $0.append(words) }
        return answer
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
    mutating func overSsh(_ device: String) -> pid_t {
        tree.tmux(under: tree.shell(under: ["/usr/sbin/sshd", "/usr/libexec/sshd-session"], on: device), on: device)
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

    /// A zmx session's server: on no tty, under launchd, its command line a client's, then any command it runs.
    @discardableResult
    mutating func zmxServer(_ session: String, running command: [String] = []) -> pid_t {
        tree.add(under: 1, zmxProgram, arguments: ["zmx", "attach", session] + command)
    }
}
