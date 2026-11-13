import Darwin
import Foundation
import SitRepCore

/// tmux, asked through its program.
public protocol TmuxProgram: Sendable {
    /// tmux on the server at a socket, given the words: how it ran. Throws `TmuxUnanswered` where it is not found,
    /// could not start or did not answer in its time.
    func run(on socket: String, _ words: [String]) async throws -> Ran
}

/// tmux's multiplexer adapter: which tmux clients show a pane, and the select that would make one show it.
///
/// A client's current tmux window, not its tmux session, is what it shows: a tmux session of several windows shows one
/// at a time, and those grouped or sharing a linked window each show their own current one. So a pane no client shows
/// is shown by selecting its window in a tmux session that holds it and has a client attached, by their ids, which
/// never change, where tmux matches a name by its start or as a pattern. The select is made only in a jump, never as
/// the screen is read.
public struct TmuxAdapter: Multiplexer {
    let tmux: any TmuxProgram

    public init(_ tmux: any TmuxProgram) {
        self.tmux = tmux
    }

    /// tmux's words for every pane with its tmux window, tmux session and device, a pane once for each tmux session
    /// its window is in; and for every client with its device, its process, the tmux window it shows and the tmux
    /// session it is attached to.
    static let panes = ["list-panes", "-a", "-F", "#{pane_id}\t#{window_id}\t#{session_id}\t#{pane_tty}"]
    static let clients = ["list-clients", "-F", "#{client_tty}\t#{client_pid}\t#{window_id}\t#{session_id}"]

    public func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.tmux != nil
    }

    public func tellsBy(_: Proc) -> Bool {
        false
    }

    /// tmux, asked twice for each socket the windows run under, each socket once.
    public func read(_ windows: [Board.Window.Where]) async -> any Reading {
        let sockets = Set(windows.compactMap(\.tmux?.socket))
        let servers = await withTaskGroup(of: (String, ServerRead).self) { group in
            for socket in sockets {
                group.addTask { (socket, await readServer(socket)) }
            }

            return await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
        }

        return TmuxReading(servers: servers)
    }

    /// A server's panes and clients. tmux exiting non-zero answers no server only where its words say none runs on
    /// the socket; any other error, a server it could not talk to, leaves the server unknown, in tmux's words. Its
    /// words are its last line, as a wrapper or the loader may write ahead of it.
    func readServer(_ socket: String) async -> ServerRead {
        async let panes = try? tmux.run(on: socket, Self.panes)
        async let clients = try? tmux.run(on: socket, Self.clients)

        guard let panes = await panes, let clients = await clients else {
            return .unanswered
        }

        guard let failed = [panes, clients].first(where: { $0.status != 0 }) else {
            return .server(TmuxServer(panes: parsePanes(panes.stdout), clients: parseClients(clients.stdout)))
        }

        let said = failed.stderr.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty } ?? ""

        return Self.saysNoServer(said) ? .noServer : .failed(said: said)
    }

    /// Whether tmux's error says no server runs on the socket, as its client words a failed connect (client.c): a
    /// socket refusing, a stale file nothing listens on, is `no server running on`; no socket file at all, `error
    /// connecting to` with `(No such file or directory)`.
    static func saysNoServer(_ said: String) -> Bool {
        said.hasPrefix("no server running on ")
            || said.hasPrefix("error connecting to ") && said.hasSuffix(" (No such file or directory)")
    }
}

/// What tmux said of a server: its panes and clients, that none runs on the socket, any other error in its words, or
/// nothing in time.
enum ServerRead: Sendable, Equatable {
    case server(TmuxServer)
    case noServer
    case failed(said: String)
    case unanswered
}

/// What a tmux server holds: each pane, by its id, and its clients.
struct TmuxServer: Sendable, Equatable {
    let panes: [String: Pane]
    let clients: [TmuxClient]
}

/// A pane: its tmux window, the tmux sessions holding that window, by their ids, and the device it is on.
struct Pane: Sendable, Equatable {
    let window: String
    var sessions: [String]
    let device: String
}

/// A tmux client: the device it is on, empty for a control-mode client over pipes, its process, the tmux window it
/// shows, and the tmux session it is attached to, by their ids.
struct TmuxClient: Sendable, Equatable {
    let device: String
    let pid: pid_t
    let window: String
    let session: String
}

/// Each line's fields where it has at least `count`, the last taking any tab left.
private func rows(_ output: String, _ count: Int) -> [[String]] {
    output.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
        let fields = line.split(separator: "\t", maxSplits: count - 1, omittingEmptySubsequences: false)

        return fields.count < count ? nil : fields.map(String.init)
    }
}

/// `list-panes -a` as each pane, the tmux sessions its window is in gathered from its lines.
func parsePanes(_ output: String) -> [String: Pane] {
    rows(output, 4).reduce(into: [:]) { panes, fields in
        var pane = panes[fields[0]] ?? Pane(window: fields[1], sessions: [], device: fields[3])

        if !pane.sessions.contains(fields[2]) {
            pane.sessions.append(fields[2])
        }

        panes[fields[0]] = pane
    }
}

/// `list-clients` as its clients; a line whose process is no number is no client.
func parseClients(_ output: String) -> [TmuxClient] {
    rows(output, 4).compactMap { fields in
        pid_t(fields[1]).map { TmuxClient(device: fields[0], pid: $0, window: fields[2], session: fields[3]) }
    }
}

/// What tmux said of its servers, by socket, as a reading of the screen.
struct TmuxReading: Reading {
    let servers: [String: ServerRead]

    private func server(_ where: Board.Window.Where) -> TmuxServer? {
        guard let socket = `where`.tmux?.socket, case let .server(server) = servers[socket] else {
            return nil
        }

        return server
    }

    func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.tmux != nil
    }

    /// Whether the window's device is its tmux pane's: nil where that cannot be told, the pane gone, its server
    /// silent, or the window saying no device, or one that is no tty.
    func isOnItsPty(_ where: Board.Window.Where) -> Bool? {
        guard let pane = `where`.tmux.flatMap({ server(`where`)?.panes[$0.pane] }), isDevice(pane.device),
              let device = `where`.tty
        else {
            return nil
        }

        return pane.device == device
    }

    /// The clients a jump can reach that show the window's pane, each seated by the table: those whose current
    /// window is the pane's; else, where none is, those attached to a tmux session holding its window, each with the
    /// select that makes it show the pane. A client a jump cannot reach, Lee's phone, neither shows the pane nor stops
    /// a select making another client show it.
    func places(_ where: Board.Window.Where, _ processes: Processes) -> [Place] {
        guard let tmux = `where`.tmux, let server = server(`where`), let pane = server.panes[tmux.pane] else {
            return []
        }

        let seated = server.clients.compactMap { client in
            processes.seat(of: client.pid, own: client.device).map { (client, $0) }
        }
        let showing = seated.filter { client, _ in client.window == pane.window }

        guard showing.isEmpty else {
            return showing.map { Place($1) }
        }

        return seated.filter { client, _ in pane.sessions.contains(client.session) }.map { client, seat in
            Place(seat, select: Select(socket: tmux.socket, session: client.session, window: pane.window))
        }
    }

    /// tmux, where it gave no answer for the window's socket, or an error other than no server, in its words: not
    /// starting, as when it is missing, is one, so a server outliving its program reads unknown, never off.
    func unanswered(_ where: Board.Window.Where) -> [Unanswered] {
        switch `where`.tmux.flatMap({ servers[$0.socket] }) {
        case .unanswered?: [.tmux]
        case let .failed(said)?: [.tmuxSaid(said)]
        default: []
        }
    }

    /// A server with clients needs the table to tell which apps they are in.
    func needsProcesses(_ where: Board.Window.Where) -> Bool {
        server(`where`)?.clients.isEmpty == false
    }
}

/// Why tmux gave no answer: not on Lee's PATH; or found, but it could not start, outran its time or was stopped.
public enum TmuxUnanswered: Error, Equatable {
    case notFound
    case unanswered(RunError)
}

/// The real tmux, told its client takes UTF-8 (`-u`): without it, run with no UTF-8 locale and no `$TMUX`, as SitRep
/// runs, a tmux 3.8 server writes each tab of a `-F` format as `_` (live, 22 October 2026). Each run has 2 seconds, and
/// is ended with its process group at its limit, as the CLI's tmux was.
///
/// It is found once, on the PATH given, so one is made for each read with Lee's PATH as it then stands: a tmux
/// installed or removed since shows at the next read.
public struct TmuxOnPath: TmuxProgram {
    static let limit: TimeInterval = 2

    private let executable: URL?
    private let environment: [String: String]
    private let runner: Runner

    public init(
        path: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        run: @escaping Runner = runProgram
    ) {
        executable = Self.find("tmux", on: path)
        self.environment = environment.merging(["PATH": path]) { _, given in given }
        runner = run
    }

    public func run(on socket: String, _ words: [String]) async throws -> Ran {
        guard let executable else {
            throw TmuxUnanswered.notFound
        }

        do {
            return try await runner(
                Program(
                    executable: executable,
                    arguments: ["-u", "-S", socket] + words,
                    environment: environment,
                    limit: Self.limit,
                    stopping: .group
                )
            )
        } catch {
            throw TmuxUnanswered.unanswered(error as? RunError ?? .unstartable(String(describing: error)))
        }
    }

    /// The first executable file of the name in the PATH's folders, as a shell finds it: never a folder.
    static func find(_ name: String, on path: String) -> URL? {
        path.split(separator: ":").lazy
            .map { URL(fileURLWithPath: String($0)).appending(path: name) }
            .first { file in
                var isFolder: ObjCBool = false

                return FileManager.default.fileExists(atPath: file.path, isDirectory: &isFolder) && !isFolder.boolValue
                    && FileManager.default.isExecutableFile(atPath: file.path)
            }
    }
}
