import Foundation
import os

/// A program to run as a child process, with no shell between.
public struct Program: Sendable, Equatable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]
    /// How long it may run before it is killed: `.infinity` for one watched, which runs for the app's life.
    public let limit: TimeInterval
    /// How it is ended at its limit, or as its task is cancelled, by `runProgram`. `WatchProgram`, which runs `watch`
    /// for the app's life and ends it its own way, does not read it.
    public let stopping: Stopping

    public init(
        executable: URL, arguments: [String], environment: [String: String], limit: TimeInterval,
        stopping: Stopping = .alone
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.limit = limit
        self.stopping = stopping
    }
}

/// How a program is ended early: killed outright (SIGKILL), as an interactive shell ignores SIGTERM.
public enum Stopping: Sendable, Equatable {
    /// It alone, killed, as a login shell is: what its startup files started, an ssh-agent among it, is not its to end.
    case alone
    /// Killed with its process group, every program it started: tmux, as a jump runs it, and the CLI.
    case group
}

/// How a program ended: its exit status, and what it printed.
public struct Ran: Sendable, Equatable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public init(status: Int32, stdout: String, stderr: String) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum RunError: Error, Equatable, CustomStringConvertible {
    case unstartable(String)
    case timedOut(TimeInterval)
    /// The task that ran it was cancelled, and it was killed.
    case stopped

    public var description: String {
        switch self {
        case let .unstartable(reason):
            "could not start: \(reason)"
        case let .timedOut(limit):
            "did not answer within \(limit.formatted()) seconds"
        case .stopped:
            "was stopped"
        }
    }
}

/// Runs a program to its end; throws a `RunError` when it cannot start, outlives its limit, or its task is cancelled.
public typealias Runner = @Sendable (Program) async throws -> Ran

/// The runner for real programs. The wait blocks, so it waits on a thread of its own, never the main one nor Swift's.
/// Its task cancelled, the program is ended as its `Stopping` says.
public let runProgram: Runner = { program in
    let running = Running(program.stopping)

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(with: Result { try runWaiting(program, running) })
            }
        }
    } onCancel: {
        running.stop()
    }
}

/// How long output is read after the program ends: a child it left behind may hold its output open.
let drainSeconds: TimeInterval = 0.5

/// Runs the program to its end, its limit or its stop, its stdin /dev/null.
/// One still running at the limit, or stopped, is ended as its `Stopping`
/// says (`Running`).
private func runWaiting(_ program: Program, _ running: Running) throws -> Ran {
    let process = Process()
    let stdout = Output()
    let stderr = Output()
    let exited = DispatchSemaphore(value: 0)

    process.executableURL = program.executable
    process.arguments = program.arguments
    process.environment = program.environment
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = stdout.pipe
    process.standardError = stderr.pipe
    process.terminationHandler = { _ in
        running.ended()
        exited.signal()
    }

    guard !running.isStopped else {
        throw RunError.stopped
    }

    do {
        try process.run()
    } catch {
        throw RunError.unstartable(error.localizedDescription)
    }

    running.started(process.processIdentifier)
    guard exited.wait(timeout: .now() + program.limit) == .success else {
        running.end()
        process.waitUntilExit()
        stdout.stop()
        stderr.stop()
        throw running.isStopped ? RunError.stopped : RunError.timedOut(program.limit)
    }

    let drained = DispatchTime.now() + drainSeconds
    let ran = Ran(status: process.terminationStatus, stdout: stdout.read(by: drained), stderr: stderr.read(by: drained))

    guard !running.isStopped else {
        throw RunError.stopped
    }

    return ran
}

/// A program as it runs, which a stop from another thread ends as its `Stopping` says: before it starts, it is never
/// started; once it has ended, it is told nothing, so no pid reused since is.
///
/// A group stop takes its process group, so nothing it started outlives it: until SitRep made its own jump, the CLI's
/// osascript, tmux and `ps` shared its group, and an osascript left running could have sent Ghostty a question late.
/// `Process` makes each child the leader of a group of its own (checked on macOS 26, 4 November 2026); a group not the
/// child's own, which would be SitRep's, is never signalled, and the child alone is.
final class Running: Sendable {
    private struct State {
        var pid: pid_t?
        var isStopped = false
        var hasEnded = false
    }

    private let stopping: Stopping
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(_ stopping: Stopping) {
        self.stopping = stopping
    }

    var isStopped: Bool { state.withLock(\.isStopped) }

    /// It started as this process; one stopped before is ended at once.
    func started(_ pid: pid_t) {
        let isStopped = state.withLock { state in
            state.pid = pid
            return state.isStopped
        }

        if isStopped {
            end()
        }
    }

    /// It is to end: ended now if it runs, and never started if it has not.
    func stop() {
        state.withLock { $0.isStopped = true }
        end()
    }

    /// Kills it, or its group where the `Stopping` says so and the group is its own, while it runs.
    func end() {
        let group = stopping == .group

        state.withLock { state in
            guard let pid = state.pid, !state.hasEnded else {
                return
            }

            _ = Darwin.kill(group && getpgid(pid) == pid ? -pid : pid, SIGKILL)
        }
    }

    func ended() {
        state.withLock { $0.hasEnded = true }
    }
}

/// What a program prints to one of its outputs, gathered as it comes.
private final class Output: Sendable {
    let pipe = Pipe()
    private let text = OSAllocatedUnfairLock(initialState: Data())
    private let closed = DispatchSemaphore(value: 0)

    init() {
        pipe.fileHandleForReading.readabilityHandler = { [text, closed] handle in
            let chunk = handle.availableData

            if chunk.isEmpty {
                handle.readabilityHandler = nil
                closed.signal()
            } else {
                text.withLock { $0.append(chunk) }
            }
        }
    }

    /// What it printed, once it closes or by the time given, whichever comes first.
    func read(by deadline: DispatchTime) -> String {
        _ = closed.wait(timeout: deadline)
        stop()

        return String(decoding: text.withLock { $0 }, as: UTF8.self)
    }

    func stop() {
        pipe.fileHandleForReading.readabilityHandler = nil
    }
}
