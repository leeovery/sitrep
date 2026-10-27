import Foundation
import os

/// How many of the last lines of stderr are kept: a run lives for the app's
/// life, and only what it said as it ended is wanted.
private let saidLines = 20

/// The longest line of stdout read whole, 16MB; one longer is cut here, and
/// so does not read. A line carries the board of each session the window
/// follows: on a copy of Lee's board on 27 October 2026, following all 81
/// sessions made a line of 626KB, and the largest session's board alone is
/// some 90KB, growing with its Resolved. `watch` counts a board printed once
/// it has written it, so a line refused here loses its boards until each
/// changes: the limit stands far above any board Lee's would come to.
let longestLine = 16 << 20

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

/// The watcher for real programs: no shell between, each line given written
/// to its standard input, and no time limit, the program's own aside.
/// Stopped with SIGTERM, which `watch` ends on, exit 0.
public let watchProgram: Watcher = { program, input in watch(program, writing: input, holding: RunningChild()) }

/// The watcher for real programs, each held by `running` while it runs.
public func watchProgram(holding running: RunningChild) -> Watcher {
    { program, input in watch(program, writing: input, holding: running) }
}

private func watch(_ program: Program, writing input: AsyncStream<String>, holding running: RunningChild) -> AsyncStream<Heard> {
    AsyncStream { heard in
        let process = Process()
        let stdin = Writer()
        let stdout = Reader(longest: longestLine)
        let stderr = Reader(longest: longestSaid)
        let exited = AsyncStream<Exit> { exited in
            process.terminationHandler = { process in
                running.release(process)
                stdin.close()
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
        process.standardInput = stdin.pipe
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
            stdin.close()
            stdout.close()
            stderr.close()
            heard.yield(.unstartable(error.localizedDescription))
            heard.finish()

            return
        }

        stdin.write(input)

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

/// A program's standard input, written a line at a time, each in turn, on a
/// queue of its own: a write to a pipe the program is slow to read waits,
/// and must never hold the main actor nor one of Swift's threads. Closed, as
/// the program ends or the lines given do, it writes nothing more. The pipe
/// never sends SIGPIPE, which would end the app: a write that finds the
/// program gone, its end of the pipe closed, fails with EPIPE, and is
/// dropped.
private final class Writer: Sendable {
    let pipe = Pipe()
    private let queue = DispatchQueue(label: "com.leeovery.sitrep.watch.input")
    /// Only `queue` reads or sets it, so no write crosses the close.
    private let isOpen = OSAllocatedUnfairLock(initialState: true)

    init() {
        _ = fcntl(pipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
    }

    /// Writes each line given, with its newline, then closes once they end.
    func write(_ lines: AsyncStream<String>) {
        Task {
            for await line in lines {
                await write(Data("\(line)\n".utf8))
            }

            close()
        }
    }

    func close() {
        queue.async { [self] in
            let wasOpen = isOpen.withLock { isOpen in
                defer { isOpen = false }
                return isOpen
            }

            if wasOpen {
                try? pipe.fileHandleForWriting.close()
            }
        }
    }

    private func write(_ data: Data) async {
        await withCheckedContinuation { written in
            queue.async { [self] in
                if isOpen.withLock({ $0 }) {
                    try? pipe.fileHandleForWriting.write(contentsOf: data)
                }

                written.resume()
            }
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
