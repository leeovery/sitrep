import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// `here.json` (DESIGN, "Storage"): at the top of the board's folder, found as core's `rootOf` finds it; its text the
/// text core's reader is held to, in `tests/here.ts`; written whole at every read, so a reader never sees half a file;
/// a failure saying nothing; and removed after every write before it.
@Suite(.backstop)
struct HereFileTests {
    /// A folder of the test's own, there, gone once the test is done with it.
    private final class Folder {
        let url = FileManager.default.temporaryDirectory.appending(path: "sitrep-here-\(UUID().uuidString)")

        init() throws {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        var file: HereFile { HereFile(url: url.appending(path: HereFile.name)) }

        var names: [String] { (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [] }

        deinit {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static let at = Date(timeIntervalSince1970: 1_763_650_000.123_4)

    /// The file as core's tests read it: the text between the backticks of `APP_FILE` in `tests/here.ts`.
    private static func coresFixture(sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../../tests/here.ts")
        let text = try String(contentsOf: file, encoding: .utf8)
        let start = try #require(text.range(of: "export const APP_FILE = `"), sourceLocation: sourceLocation)

        return String(text[start.upperBound...].prefix { $0 != "`" })
    }

    private static func read(_ file: HereFile) throws -> String {
        try String(contentsOf: file.url, encoding: .utf8)
    }

    /// The app's file and the panel's reader agree: what the app writes for these sessions at this time is, byte for
    /// byte, the file core's tests read as them, the time cut to the whole millisecond and the sessions in order.
    @Test func itsTextIsTheFileCoresReaderIsHeldTo() throws {
        let text = try HereFile.text(["sr-nw0001", "sr-ct0002"], at: Self.at)

        #expect(String(decoding: text, as: UTF8.self) == (try Self.coresFixture()))
    }

    @Test func theSameReadAtTheSameTimeIsAlwaysTheSameBytes() throws {
        let sessions: Set = ["sr-tw0003", "sr-nw0001", "sr-ct0002", "sr-fb0004"]

        #expect(try HereFile.text(sessions, at: Self.at) == HereFile.text(Set(sessions.reversed()), at: Self.at))
        #expect(try String(decoding: HereFile.text([], at: Self.at), as: UTF8.self) == #"{"at":1763650000123,"notHere":[],"v":1}"#)
    }

    /// `$XDG_STATE_HOME/sitrep` where it names a folder from the root; else under `$HOME`, or the home given where
    /// `HOME` names none, as core's `rootOf` has it, a relative one passed over.
    @Test(arguments: [
        (["XDG_STATE_HOME": "/state/", "HOME": "/Users/me"], "/state/sitrep/here.json"),
        (["XDG_STATE_HOME": "state", "HOME": "/Users/me"], "/Users/me/.local/state/sitrep/here.json"),
        ([:], "/Users/given/.local/state/sitrep/here.json"),
    ])
    func itSitsAtTheTopOfTheBoardsFolder(environment: [String: String], path: String) {
        let file = HereFile(environment: environment, home: URL(filePath: "/Users/given"))

        #expect(file.url.standardizedFileURL.path(percentEncoded: false) == path)
    }

    /// Written into the board's folder, the file alone left in it.
    @Test func itIsWrittenAndNothingLeftBesideIt() throws {
        let folder = try Folder()

        folder.file.write(["sr-nw0001"], at: Self.at)

        #expect(try Data(contentsOf: folder.file.url) == HereFile.text(["sr-nw0001"], at: Self.at))
        #expect(folder.names == [HereFile.name])
    }

    /// Written whole, beside the file then renamed over it: a reader holding the file open as it is written still
    /// reads the old whole, never the new one half written over it, and the next to open it reads the new whole.
    @Test func itIsWrittenWholeAReaderNeverSeesHalfAFile() throws {
        let folder = try Folder()
        let file = folder.file

        file.write(["sr-nw0001"], at: Self.at)

        let reader = try FileHandle(forReadingFrom: file.url)

        defer { try? reader.close() }
        file.write(["sr-ct0002", "sr-fb0004"], at: Self.at.addingTimeInterval(3))

        #expect(try reader.readToEnd() == HereFile.text(["sr-nw0001"], at: Self.at))
        #expect(try Data(contentsOf: file.url) == HereFile.text(["sr-ct0002", "sr-fb0004"], at: Self.at.addingTimeInterval(3)))
    }

    /// A write that fails makes nothing: into a board folder not there, which it never makes; and into one that is a
    /// file.
    @Test func aWriteThatFailsGoesNoFurther() throws {
        let folder = try Folder()
        let missing = folder.url.appending(path: "sitrep")
        let blocker = folder.url.appending(path: "blocked")

        HereFile(url: missing.appending(path: HereFile.name)).write(["sr-nw0001"], at: Self.at)
        #expect(!FileManager.default.fileExists(atPath: missing.path))

        try Data("not a folder".utf8).write(to: blocker)
        HereFile(url: blocker.appending(path: HereFile.name)).write(["sr-nw0001"], at: Self.at)
        #expect(try String(contentsOf: blocker, encoding: .utf8) == "not a folder")
        #expect(folder.names == ["blocked"])
    }

    /// The first of a run of failures is logged, and no other until a write succeeds: one line, never one a read.
    @Test func aRunOfFailuresIsLoggedOnce() throws {
        let folder = try Folder()
        let logged = OSAllocatedUnfairLock(initialState: [String]())
        let file = HereFile(url: folder.url.appending(path: "board/\(HereFile.name)")) { line in
            logged.withLock { $0.append(line) }
        }
        let board = folder.url.appending(path: "board")

        for _ in 0 ..< 3 {
            file.write(["sr-nw0001"], at: Self.at)
        }
        #expect(logged.withLock { $0.count } == 1)
        #expect(logged.withLock { $0.first?.hasPrefix("here.json was not written: ") } == true)

        try FileManager.default.createDirectory(at: board, withIntermediateDirectories: true)
        file.write(["sr-nw0001"], at: Self.at)
        try FileManager.default.removeItem(at: board)
        file.write(["sr-nw0001"], at: Self.at)
        file.write(["sr-nw0001"], at: Self.at)
        #expect(logged.withLock { $0.count } == 2, "logged again only after a write succeeded")
    }

    /// Posted reads are written off the caller's thread, each in the order posted, so the last read stands.
    @Test func readsPostedAreWrittenInTurn() throws {
        let folder = try Folder()
        let file = folder.file

        for second in 0 ..< 10 {
            file.post(["sr-nw000\(second)"], at: Self.at.addingTimeInterval(TimeInterval(second)))
        }
        file.flush()

        #expect(try Data(contentsOf: file.url) == HereFile.text(["sr-nw0009"], at: Self.at.addingTimeInterval(9)))
    }

    /// A read with nothing dimmed removes the file, a file left by a run before among it, once and in turn after the
    /// writes posted before it; more such reads remove nothing, until a write.
    @Test func aReadWithNothingDimmedRemovesTheFileOnce() throws {
        let folder = try Folder()
        let file = folder.file
        let other = try HereFile.text(["sr-ct0002"], at: Self.at)

        try other.write(to: file.url)
        file.post([], at: Self.at)
        file.flush()
        #expect(folder.names.isEmpty, "a file left by a run before")

        try other.write(to: file.url)
        file.post([], at: Self.at)
        file.flush()
        #expect(try Data(contentsOf: file.url) == other, "removed once: nothing more till a write")

        file.post(["sr-nw0001"], at: Self.at)
        file.post([], at: Self.at)
        file.flush()
        #expect(folder.names.isEmpty, "removed after the write posted before it")
    }

    /// Removed once every write posted before it is done, so none brings it back; removing a file not there says
    /// nothing.
    @Test func itIsRemovedAfterEveryWritePostedBeforeIt() throws {
        let folder = try Folder()
        let file = folder.file

        file.remove()
        for second in 0 ..< 10 {
            file.post(["sr-nw0001"], at: Self.at.addingTimeInterval(TimeInterval(second)))
        }
        file.remove()

        #expect(folder.names.isEmpty)
    }

    /// The removal at quit waits up to its limit on a write hung before it, then returns, the file left to go stale;
    /// it lands once the write is done.
    @Test func theRemovalAtQuitNeverWaitsPastItsLimit() throws {
        let folder = try Folder()
        let file = folder.file
        let hung = DispatchSemaphore(value: 0)

        file.write(["sr-nw0001"], at: Self.at)
        file.queue.async { hung.wait() }

        let started = ContinuousClock.now

        file.remove(within: .milliseconds(200))

        #expect(ContinuousClock.now - started < .seconds(5))
        #expect(folder.names == [HereFile.name], "still standing behind the hung write")

        hung.signal()
        file.flush()
        #expect(folder.names.isEmpty)
    }
}
