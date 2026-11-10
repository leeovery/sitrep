import Foundation
import SitRepCore

/// zmx's multiplexer adapter. A zmx session is one terminal, shown whole by every client attached to it, so there is no
/// window or pane to select. zmx 1.0.1 lists no session's clients, so they are read from the process table: each
/// process of zmx's program, on a tty, whose command line is exactly `zmx attach <session>`, by any path to zmx, the
/// name compared whole, in order of process id: the oldest client first, until ids wrap round. The session's own server is on no tty, under launchd (live, 9
/// November 2026), so it is no client, and its command line is never read.
///
/// Only a process whose program's file is named `zmx` has its command line read, which keeps the reads to a few a look;
/// the CLI read every process's from `ps`. So a zmx installed under another name reads off screen.
///
/// A client switched in place, `zmx attach B` typed inside an attach on A, keeps A's name in its command line, and so
/// reads as A's: a known limit, as Portal's own switch starts a fresh `zmx attach B`.
public struct ZmxAdapter: Multiplexer {
    /// zmx's words for its sessions' names, one a line.
    static let sessions = ["list", "--short"]

    let zmx: any ZmxProgram

    public init(_ zmx: any ZmxProgram) {
        self.zmx = zmx
    }

    public let kind = MultiplexerKind.zmx

    public func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.zmx != nil
    }

    /// A process of zmx's program on a tty, which may be a client: only its command line tells whose.
    public func tellsBy(_ process: Proc) -> Bool {
        process.device != nil && process.program?.split(separator: "/").last == "zmx"
    }

    /// zmx asks nothing of its own: its clients, and so which apps show its windows, are told by the table alone.
    public func read(_: [Board.Window.Where]) async -> any Reading {
        ZmxReading()
    }

    /// The session's name, the window's `$ZMX_SESSION`, fixed for the session's life: zmx renames nothing, and
    /// Portal's `rename` sets a label of its own.
    public func attachValues(_ where: Board.Window.Where, wanted _: Set<Placeholder>) async throws
        -> [Placeholder: String]
    {
        `where`.zmx.map { [.session: $0.session] } ?? [:]
    }

    /// Whether zmx has the session, as a window beats on up to 90 seconds after its Claude dies unseen, its session
    /// killed or crashed, and `zmx attach` would make it anew, empty: one it does not list is gone (`SessionGone`).
    /// zmx listing none at all, while a live window says it runs in one, is not taken for its session gone: most
    /// likely this zmx looks for its sessions in another folder than the window's, `ZMX_DIR` set where SitRep's
    /// environment does not reach.
    public func confirm(_ where: Board.Window.Where) async throws {
        guard let session = `where`.zmx?.session else {
            throw SessionGone()
        }

        let listed = try await listed()

        guard !listed.isEmpty else {
            throw Unattachable(description: Self.noneListed)
        }
        guard listed.contains(session) else {
            throw SessionGone()
        }
    }

    static let noneListed = "zmx lists no sessions at all, though this session runs in one, so SitRep's zmx most "
        + "likely does not see the folder your shell keeps zmx's sessions in (ZMX_DIR)."

    /// The names of the sessions zmx has; its silence or its error a refusal, in its words where it gave any.
    private func listed() async throws -> Set<String> {
        let asked = "zmx, asked which sessions it has,"
        let ran: Ran

        do {
            ran = try await zmx.run(Self.sessions)
        } catch let unanswered as ProgramUnanswered {
            throw Unattachable(description: unanswered.words(asked: asked))
        }

        let said = ran.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

        guard ran.status == 0 else {
            throw Unattachable(description: said.isEmpty ? "\(asked) failed (\(ran.status))." : "\(asked) said \"\(said)\".")
        }

        return Set(ran.stdout.split(separator: "\n").map(String.init))
    }
}

/// zmx, asked through its program.
public protocol ZmxProgram: Sendable {
    /// zmx given the words: how it ran. Throws `ProgramUnanswered` where it is not found, could not start or did not
    /// answer in its time.
    func run(_ words: [String]) async throws -> Ran
}

/// The real zmx, found on Lee's PATH and run with his login shell's environment, 2 seconds a run (`ProgramOnPath`).
public struct ZmxOnPath: ZmxProgram {
    private let zmx: ProgramOnPath

    public init(environment: [String: String], run: @escaping Runner = runProgram) {
        zmx = ProgramOnPath("zmx", environment: environment, run: run)
    }

    public func run(_ words: [String]) async throws -> Ran {
        try await zmx.run(words)
    }
}

struct ZmxReading: Reading {
    let kind = MultiplexerKind.zmx

    func isIn(_ where: Board.Window.Where) -> Bool {
        `where`.zmx != nil
    }

    /// A live window in zmx is its session's proof of life: zmx lists nothing SitRep reads.
    func holds(_ where: Board.Window.Where) -> Bool {
        isIn(`where`)
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

    /// Whether a command line attaches to the session as a client: `zmx attach <session>`, by any path to zmx, and
    /// nothing after.
    static func attaches(_ arguments: [String]?, to session: String) -> Bool {
        guard let arguments, arguments.count == 3, let zmx = arguments.first else {
            return false
        }

        return (zmx == "zmx" || zmx.hasSuffix("/zmx")) && arguments[1] == "attach" && arguments[2] == session
    }
}
