import Foundation
import os

/// How many of the last lines of stderr are kept: a run lives for the app's
/// life, and only what it said as it ended is wanted.
private let saidLines = 20

/// The longest line of stdout read whole. A board's line was some 16KB over
/// Lee's board of 12 projects on 19 October 2026, and grows with the board;
/// one longer is cut here, and so does not read.
let longestLine = 1 << 20

/// The longest line of stderr kept: what it says fits a menu item.
let longestSaid = 1024

/// The program a watcher has running, held so that it can be stopped at
/// once: a cancelled iteration sends its SIGTERM on a thread of its own,
/// which an app quitting may outrun. Once stopped it stays so: a program
/// held after, one started as the stop came, is sent SIGTERM as it is
/// held, since what it says may be heard before then.
public final class RunningChild: Sendable {
    private struct Held {
        var process: Process?
        var isStopped = false
    }

    private let held = OSAllocatedUnfairLock(initialState: Held())

    public init() {}

    /// Sends the running program SIGTERM now, if there is one, and any
    /// held from now on as it is.
    public func terminate() {
        let process = held.withLock { held in
            held.isStopped = true
            return held.process
        }

        process.map(Self.stop)
    }

    fileprivate func hold(_ process: Process) {
        let isStopped = held.withLock { held in
            held.process = process
            return held.isStopped
        }

        if isStopped {
            Self.stop(process)
        }
    }

    fileprivate func release(_ process: Process) {
        held.withLock { held in
            if held.process === process {
                held.process = nil
            }
        }
    }

    private static func stop(_ process: Process) {
        if process.isRunning {
            process.terminate()
        }
    }
}

/// The watcher for real programs: no shell between, stdin from /dev/null,
/// and no time limit, the program's own aside. Stopped with SIGTERM, which
/// `watch` ends on, exit 0.
public let watchProgram: Watcher = { program in watch(program, holding: RunningChild()) }

/// The watcher for real programs, each held by `running` while it runs.
public func watchProgram(holding running: RunningChild) -> Watcher {
    { program in watch(program, holding: running) }
}

private func watch(_ program: Program, holding running: RunningChild) -> AsyncStream<Heard> {
    AsyncStream { heard in
        let process = Process()
        let stdout = Reader(longest: longestLine)
        let stderr = Reader(longest: longestSaid)
        let exited = AsyncStream<Exit> { exited in
            process.terminationHandler = { process in
                running.release(process)
                exited.yield(process.exit)
                exited.finish()
                DispatchQueue.global().asyncAfter(deadline: .now() + drainSeconds) {
                    stdout.close()
                    stderr.close()
                }
            }
        }

        process.executableURL = program.executable
        process.arguments = program.arguments
        process.environment = program.environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe

        heard.onTermination = { ending in
            if case .cancelled = ending, process.isRunning {
                process.terminate()
            }
        }

        do {
            try process.run()
            running.hold(process)
        } catch {
            stdout.close()
            stderr.close()
            heard.yield(.unstartable(error.localizedDescription))
            heard.finish()

            return
        }

        Task {
            async let said = last(saidLines, of: stderr.lines)

            for await line in stdout.lines {
                heard.yield(.line(line))
            }

            for await exit in exited {
                heard.yield(.exited(exit, stderr: await said))
            }

            heard.finish()
        }
    }
}

private extension Process {
    var exit: Exit {
        terminationReason == .uncaughtSignal ? .signal(terminationStatus) : .status(terminationStatus)
    }
}

/// One of a program's outputs, read as lines until it closes, or until it
/// is closed, as a child the program left behind may hold it open. It is
/// read on a queue of its own: a read waits, and must never hold one of
/// Swift's threads for the program's life, as `FileHandle.bytes` does.
private final class Reader: Sendable {
    let pipe = Pipe()
    let lines: AsyncStream<String>
    private let line: AsyncStream<String>.Continuation
    private let buffer: OSAllocatedUnfairLock<LineBuffer>

    init(longest: Int) {
        (lines, line) = AsyncStream.makeStream()
        buffer = OSAllocatedUnfairLock(initialState: LineBuffer(longest: longest))
        pipe.fileHandleForReading.readabilityHandler = { [self] handle in
            let chunk = handle.availableData

            if chunk.isEmpty {
                close()
            } else {
                buffer.withLock { $0.lines(adding: chunk).forEach { line.yield($0) } }
            }
        }
    }

    /// Reads no more: what is left unended is the last line.
    func close() {
        pipe.fileHandleForReading.readabilityHandler = nil
        buffer.withLock { buffer in
            if let rest = buffer.rest() {
                line.yield(rest)
            }

            line.finish()
        }
    }
}

private func last(_ count: Int, of lines: AsyncStream<String>) async -> String {
    var kept: [String] = []

    for await line in lines {
        kept.append(line)

        if kept.count > count {
            kept.removeFirst()
        }
    }

    return kept.joined(separator: "\n")
}
