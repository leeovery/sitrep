import Darwin
import Foundation

/// A pipe in the file system that a child program writes a line to once it is ready, which the test reads before it
/// acts on the child: a named pipe, so the read waits on the line, however long the child takes to come to it.
struct Handshake {
    let path: String

    init() throws {
        path = FileManager.default.temporaryDirectory.appending(path: "sitrep-ready-\(UUID().uuidString)").path

        guard mkfifo(path, 0o600) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    /// The line the child wrote, once it has written it and let the pipe go. Read on a thread of its own, never one of
    /// Swift's, as opening the pipe waits on the child to open it too.
    func line() async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { [path] in
                let read = (try? FileHandle(forReadingAtPath: path)?.readToEnd()) ?? nil

                continuation.resume(
                    returning: String(decoding: read ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }
    }

    func remove() {
        unlink(path)
    }
}
