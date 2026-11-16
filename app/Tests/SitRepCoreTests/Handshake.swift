import Darwin
import Foundation
import Testing

/// A named pipe that a child program writes a line to once it is ready, which the test reads, within a time, before it
/// acts on the child. The pipe goes with the handshake, however the test ends, so long as no task outlives the test
/// holding it: a task given the child's program, its path in it, holds a string, never the handshake.
final class Handshake: Sendable {
    let path: String

    init() throws {
        path = FileManager.default.temporaryDirectory.appending(path: "sitrep-ready-\(UUID().uuidString)").path

        guard mkfifo(path, 0o600) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    deinit {
        unlink(path)
    }

    /// The line the child wrote; none within the time, from the call, ends the test at the caller. Read on a thread of
    /// its own, never one of Swift's, as the read waits.
    func line(within limit: Duration = .seconds(10), sourceLocation: SourceLocation = #_sourceLocation) async throws -> String {
        let deadline = ContinuousClock.now + limit
        let read = await withCheckedContinuation { continuation in
            DispatchQueue.global().async { [path] in
                continuation.resume(returning: Self.line(at: path, by: deadline))
            }
        }

        switch read {
        case let .success(line):
            return line
        case let .failure(why):
            let line: String? = nil

            return try #require(line, "No line from the child: \(why.words)", sourceLocation: sourceLocation)
        }
    }

    /// The pid the child wrote, as `line(within:)` reads it.
    func pid(within limit: Duration = .seconds(10), sourceLocation: SourceLocation = #_sourceLocation) async throws -> pid_t {
        let said = try await line(within: limit, sourceLocation: sourceLocation)

        return try #require(pid_t(said), "the child wrote no pid: \(said)", sourceLocation: sourceLocation)
    }

    private struct Failed: Error {
        let words: String
    }

    /// The pipe's first line, once whole. Opened without waiting on a writer: on macOS a poll then shows nothing until
    /// a writer has written, even once one has come and gone with nothing said, so the read ends at the line or at the
    /// time.
    private static func line(at path: String, by deadline: ContinuousClock.Instant) -> Result<String, Failed> {
        let pipe = open(path, O_RDONLY | O_NONBLOCK)

        guard pipe >= 0 else {
            return .failure(Failed(words: "open: \(String(cString: strerror(errno)))"))
        }
        defer { close(pipe) }

        var said = Data()
        var chunk = [UInt8](repeating: 0, count: 256)

        while !said.contains(UInt8(ascii: "\n")) {
            let left = deadline - ContinuousClock.now
            var ready = pollfd(fd: pipe, events: Int16(POLLIN), revents: 0)
            let polled = left > .zero ? poll(&ready, 1, Int32(left / .milliseconds(1))) : 0

            if polled < 0, errno == EINTR {
                continue
            }
            guard polled > 0 else {
                return .failure(Failed(words: polled == 0 ? "none within the time" : "poll: \(String(cString: strerror(errno)))"))
            }

            let count = read(pipe, &chunk, chunk.count)

            if count < 0, errno != EINTR, errno != EAGAIN {
                return .failure(Failed(words: "read: \(String(cString: strerror(errno)))"))
            }
            said.append(contentsOf: chunk.prefix(max(count, 0)))
        }

        return .success(String(decoding: said.prefix { $0 != UInt8(ascii: "\n") }, as: UTF8.self))
    }
}

/// Kills the process group the leader leads, with every program in it, as a test ends: `Process` makes each program
/// it starts a group's leader, and what the program starts is in its group.
func endGroup(of leader: pid_t?) {
    if let leader {
        kill(-leader, SIGKILL)
    }
}
