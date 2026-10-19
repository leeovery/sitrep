import Foundation
import os

/// A program to run as a child process: no shell between, stdin from /dev/null.
public struct Program: Sendable, Equatable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]
    /// How long it may run before it is killed: `.infinity` for one watched, which runs for the app's life.
    public let limit: TimeInterval

    public init(executable: URL, arguments: [String], environment: [String: String], limit: TimeInterval) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.limit = limit
    }
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

    public var description: String {
        switch self {
        case let .unstartable(reason):
            "could not start: \(reason)"
        case let .timedOut(limit):
            "did not answer within \(limit.formatted()) seconds"
        }
    }
}

/// Runs a program to its end; throws a `RunError` when it cannot start or outlives its limit.
public typealias Runner = @Sendable (Program) async throws -> Ran

/// The runner for real programs. The wait blocks, so it waits on a thread of its own, never the main one nor Swift's.
public let runProgram: Runner = { program in
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global().async {
            continuation.resume(with: Result { try runWaiting(program) })
        }
    }
}

/// How long output is read after the program ends: a child it left behind may hold its output open.
private let drainSeconds: TimeInterval = 0.5

/// Runs the program to its end or its limit. One still running at the limit is
/// killed outright: an interactive shell ignores SIGTERM.
private func runWaiting(_ program: Program) throws -> Ran {
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
    process.terminationHandler = { _ in exited.signal() }

    do {
        try process.run()
    } catch {
        throw RunError.unstartable(error.localizedDescription)
    }

    guard exited.wait(timeout: .now() + program.limit) == .success else {
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
        stdout.stop()
        stderr.stop()
        throw RunError.timedOut(program.limit)
    }

    let drained = DispatchTime.now() + drainSeconds

    return Ran(status: process.terminationStatus, stdout: stdout.read(by: drained), stderr: stderr.read(by: drained))
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
