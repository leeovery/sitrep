import Darwin
import Foundation
import SitRepTestSupport
import Testing

/// A named pipe that a child program writes a line to once it is ready, which the test reads, within a time, before it
/// acts on the child. The pipe goes with the handshake, however the test ends, so long as no task outlives the test
/// holding it: a task given the child's program, its path in it, holds a string, never the handshake.
///
/// A child's writing waits on the test opening the pipe to read, so a program that leaves a child of its own opens that
/// child's pipe before starting it (`exec 3> pipe`): the child starts only once the test, its group's leader read
/// (`leader(within:)`), asks for its pid, and a test that never learnt the leader leaves no child behind.
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

    /// Generous: it bounds only a child that never writes, and a healthy `sh` can be slow to start on a loaded Mac.
    static let wait = Duration.seconds(30)

    /// The line the child wrote; none within the time, from the call, ends the test at the caller. Read on a thread of
    /// its own, never one of Swift's, as the read waits.
    func line(within limit: Duration = wait, sourceLocation: SourceLocation = #_sourceLocation) async throws -> String {
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
            Issue.record("\(why)", sourceLocation: sourceLocation)
            throw why
        }
    }

    /// The pid the child wrote, as `line(within:)` reads it.
    func pid(within limit: Duration = wait, sourceLocation: SourceLocation = #_sourceLocation) async throws -> pid_t {
        let said = try await line(within: limit, sourceLocation: sourceLocation)

        return try #require(pid_t(said), "the child wrote no pid: \(said)", sourceLocation: sourceLocation)
    }

    /// The pid the child wrote, as `pid(within:)` reads it, of the leader of its process group, which the backstop
    /// watches from now until `endGroup(of:)`.
    func leader(
        within limit: Duration = wait, sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> pid_t {
        let leader = try await pid(within: limit, sourceLocation: sourceLocation)

        watchGroup(of: leader)
        return leader
    }

    private struct Failed: Error, CustomStringConvertible {
        let words: String

        var description: String { "No line from the child: \(words)" }
    }

    /// How long a poll of the pipe waits before the pipe is read all the same.
    private static let slice = Duration.milliseconds(50)

    /// The pipe's first line, once whole or once its writer lets the pipe go; none by the time, a failure. Opened
    /// without waiting on a writer, the pipe reads, on macOS, as at its end (a read of 0) until a writer comes, open and
    /// empty (EAGAIN) while one is there, and at its end again once it has gone, which a poll never shows: so it is
    /// polled a slice at a time and read after each, and at its end once something was said, it has said all it will.
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

            guard left > .zero else {
                return .failure(Failed(words: "none within the time"))
            }
            if poll(&ready, 1, Int32(min(left, slice) / .milliseconds(1))) < 0, errno != EINTR {
                return .failure(Failed(words: "poll: \(String(cString: strerror(errno)))"))
            }

            let count = read(pipe, &chunk, chunk.count)

            if count == 0, !said.isEmpty {
                break
            }
            if count < 0, errno != EINTR, errno != EAGAIN {
                return .failure(Failed(words: "read: \(String(cString: strerror(errno)))"))
            }
            said.append(contentsOf: chunk.prefix(max(count, 0)))
        }

        return .success(String(decoding: said.prefix { $0 != UInt8(ascii: "\n") }, as: UTF8.self))
    }
}

/// Whether the process runs: there, and no zombie, which `kill(pid, 0)` would count as running.
func isAlive(_ pid: pid_t) -> Bool {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)

    return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size && info.pbi_status != SZOMB
}
