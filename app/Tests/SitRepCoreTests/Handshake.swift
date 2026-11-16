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

    /// The line the child wrote, or nil, failing the test at the caller, where it wrote none within the time. Read on a
    /// thread of its own, never one of Swift's, as the read waits; opened not to wait on the child, and polled to the
    /// time, so the read always ends.
    func line(within limit: Duration = .seconds(10), sourceLocation: SourceLocation = #_sourceLocation) async -> String? {
        let read = await withCheckedContinuation { continuation in
            DispatchQueue.global().async { [path] in
                continuation.resume(returning: Self.line(at: path, by: ContinuousClock.now + limit))
            }
        }

        switch read {
        case let .success(line):
            return line
        case let .failure(why):
            Issue.record("No line from the child: \(why.words)", sourceLocation: sourceLocation)
            return nil
        }
    }

    private struct Failed: Error {
        let words: String
    }

    /// The pipe's first line, once whole, or once the child has let the pipe go: opened without waiting on a writer,
    /// whose absence a poll on macOS reports as nothing to read.
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

            guard left > .zero, poll(&ready, 1, Int32(left / .milliseconds(1))) > 0 else {
                return .failure(Failed(words: "none within the time"))
            }

            let count = read(pipe, &chunk, chunk.count)

            if count < 0, errno != EAGAIN {
                return .failure(Failed(words: "read: \(String(cString: strerror(errno)))"))
            }
            if count == 0 {
                break
            }
            said.append(contentsOf: chunk.prefix(max(count, 0)))
        }

        let line = String(decoding: said, as: UTF8.self).split(separator: "\n").first.map(String.init) ?? ""

        return line.isEmpty ? .failure(Failed(words: "the pipe closed with nothing on it")) : .success(line)
    }
}
