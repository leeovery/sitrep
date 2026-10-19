import Foundation
import os

/// What a run of `sitrep watch` says: each line it prints, then how it ended.
public enum Heard: Sendable, Equatable {
    case line(String)
    case exited(status: Int32, stderr: String)
    case unstartable(String)
}

/// Runs a program meant to run for the app's life: what it says, as it says
/// it. Ending the iteration of what it says stops it.
public typealias Watcher = @Sendable (Program) -> AsyncStream<Heard>

/// How the app hears the board: one `sitrep watch`, its child, started again
/// after a back-off whenever it ends.
public struct SitRepWatch<C: Clock>: Sendable where C.Duration == Duration {
    let cli: SitRepCLI
    let watcher: Watcher
    let clock: C

    public init(cli: SitRepCLI, watcher: @escaping Watcher = watchProgram, clock: C) {
        self.cli = cli
        self.watcher = watcher
        self.clock = clock
    }

    /// The board as it changes. Every one is kept for a reader that falls
    /// behind, since each line's `new` is told once. Ending the iteration, or
    /// cancelling its task, stops `watch`: the app does so as it quits.
    public func boards() -> AsyncStream<LastBoard> {
        AsyncStream { boards in
            let watching = Task { await watch(into: boards) }

            boards.onTermination = { _ in watching.cancel() }
        }
    }

    private func watch(into boards: AsyncStream<LastBoard>.Continuation) async {
        var last = LastBoard()
        var backoff = Backoff()

        while !Task.isCancelled {
            let started = clock.now

            for await heard in watcher(await cli.program(["watch"], limit: .infinity)) {
                if last.hear(heard), case .terminated = boards.yield(last) {
                    return
                }
            }

            guard !Task.isCancelled else {
                break
            }

            let wait = backoff.wait(after: started.duration(to: clock.now))
            let why = last.stale?.description ?? "saying nothing"

            logger.notice("sitrep watch ended, \(why, privacy: .public): starting it again in \(wait, privacy: .public)")

            try? await clock.sleep(for: wait)
        }

        boards.finish()
    }
}

extension SitRepWatch where C == ContinuousClock {
    public init(cli: SitRepCLI, watcher: @escaping Watcher = watchProgram) {
        self.init(cli: cli, watcher: watcher, clock: ContinuousClock())
    }
}

private let logger = Logger(sitrep: "watch")

/// How many of the last lines of stderr are kept: a run lives for the app's
/// life, and only what it said as it ended is wanted.
private let saidLines = 20

/// The watcher for real programs: no shell between, stdin from /dev/null,
/// and no time limit, the program's own aside. Stopped with SIGTERM, which
/// `watch` ends on, exit 0.
public let watchProgram: Watcher = { program in
    AsyncStream { heard in
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let exited = AsyncStream<Int32> { exited in
            process.terminationHandler = { exited.yield($0.terminationStatus); exited.finish() }
        }

        process.executableURL = program.executable
        process.arguments = program.arguments
        process.environment = program.environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr

        heard.onTermination = { ending in
            if case .cancelled = ending, process.isRunning {
                process.terminate()
            }
        }

        do {
            try process.run()
        } catch {
            heard.yield(.unstartable(error.localizedDescription))
            heard.finish()

            return
        }

        let printed = lines(of: stdout.fileHandleForReading)
        let complained = lines(of: stderr.fileHandleForReading)

        Task {
            async let said = last(saidLines, of: complained)

            for await line in printed {
                heard.yield(.line(line))
            }

            for await status in exited {
                heard.yield(.exited(status: status, stderr: await said))
            }

            heard.finish()
        }
    }
}

/// The lines read from the handle until it closes. They are read on a queue
/// of the handle's own: a read waits, and must never hold one of Swift's
/// threads for the program's life, as `FileHandle.bytes` does.
private func lines(of handle: FileHandle) -> AsyncStream<String> {
    AsyncStream { lines in
        let buffer = OSAllocatedUnfairLock(initialState: LineBuffer())

        handle.readabilityHandler = { handle in
            let chunk = handle.availableData

            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                if let rest = buffer.withLock({ $0.rest() }) {
                    lines.yield(rest)
                }

                lines.finish()

                return
            }

            buffer.withLock { $0.lines(adding: chunk) }.forEach { lines.yield($0) }
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

/// Output as it comes, in chunks, made lines: a line is whole once its
/// newline comes. Blank lines are dropped, as nothing is said in them.
struct LineBuffer {
    private static let newline = UInt8(ascii: "\n")

    private var unended = Data()

    /// The lines the chunk ends; what it leaves unended is kept for the next.
    mutating func lines(adding chunk: Data) -> [String] {
        unended.append(chunk)

        guard let end = unended.lastIndex(of: Self.newline) else {
            return []
        }

        let ended = unended[..<end]

        unended = Data(unended[unended.index(after: end)...])

        return ended.split(separator: Self.newline).map { String(decoding: $0, as: UTF8.self) }
    }

    /// What was left unended as the output closed.
    mutating func rest() -> String? {
        defer { unended = Data() }

        return unended.isEmpty ? nil : String(decoding: unended, as: UTF8.self)
    }
}

