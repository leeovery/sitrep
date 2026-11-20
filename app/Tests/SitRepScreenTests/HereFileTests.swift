import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// `here.json` (DESIGN, "Storage"): at the top of the board's folder, found as core's `rootOf` finds it; its text the
/// text core's reader is held to, in `tests/here.ts`; written whole, so a reader never sees half a file, at once on a
/// change and otherwise every `HereFile.refresh`; a failure saying nothing; and removed after every write before it.
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

    /// The addresses `tests/here.ts` gives Lee's phone, one IPv4 and one IPv6.
    private static let phone = Viewer.ssh("192.0.2.7")
    private static let phoneV6 = Viewer.ssh("2001:db8::7")

    /// The sessions given, each seen by nobody, so dimmed on every device.
    private static func dimmed(_ sessions: String...) -> Sightings {
        Sightings(sessions: Dictionary(uniqueKeysWithValues: sessions.map { ($0, []) }))
    }

    /// The text between the backticks of the constant named in `tests/here.ts`, which core's tests read.
    private static func coresFixture(
        _ name: String = "APP_FILE", sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> String {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../../tests/here.ts")
        let text = try String(contentsOf: file, encoding: .utf8)
        let start = try #require(text.range(of: "export const \(name) = `"), sourceLocation: sourceLocation)

        return String(text[start.upperBound...].prefix { $0 != "`" })
    }

    private static func read(_ file: HereFile) throws -> String {
        try String(contentsOf: file.url, encoding: .utf8)
    }

    /// The app's file and the panel's reader agree: what the app writes for these viewers at this time is, byte for
    /// byte, the file core's tests read as them, the time cut to the whole millisecond, each map and each list in
    /// order, a tty's slashes as they are.
    @Test func itsTextIsTheFileCoresReaderIsHeldTo() throws {
        let sightings = Sightings(
            sessions: ["sr-nw0001": [Self.phone, .mac], "sr-fb0003": [], "sr-ct0002": [Self.phoneV6, Self.phone]],
            ttys: ["/dev/ttys1024": [.mac], "/dev/ttys004": [Self.phone]]
        )

        #expect(String(decoding: try HereFile.text(sightings, at: Self.at), as: UTF8.self) == (try Self.coresFixture()))
    }

    @Test func theSameReadAtTheSameTimeIsAlwaysTheSameBytes() throws {
        let viewers: [Viewer] = [Self.phoneV6, .mac, Self.phone, .ssh("198.51.100.4")]
        let sessions = ["sr-tw0003", "sr-nw0001", "sr-ct0002", "sr-fb0004"]
        let forth = Sightings(
            sessions: Dictionary(uniqueKeysWithValues: sessions.map { ($0, Set(viewers)) }), ttys: ["/dev/ttys004": Set(viewers)]
        )
        let back = Sightings(
            sessions: Dictionary(uniqueKeysWithValues: sessions.reversed().map { ($0, Set(viewers.reversed())) }),
            ttys: ["/dev/ttys004": Set(viewers.reversed())]
        )

        #expect(try HereFile.text(forth, at: Self.at) == HereFile.text(back, at: Self.at))
        #expect(
            try String(decoding: HereFile.text(Sightings(), at: Self.at), as: UTF8.self)
                == #"{"at":1763650000123,"sessions":{},"ttys":{},"v":2}"#
        )
    }

    /// A tty `ttys` names is the one the panel looks itself up by: the device the kernel's numbers for each process's
    /// terminal name is the one core's `ttyOf` names from the same numbers, as Bun's `fstatSync` gives them, the pairs
    /// in `tests/here.ts` both suites read.
    @Test func aTtysDeviceIsNamedAsThePanelNamesItsOwn() throws {
        let pairs = try #require(
            JSONSerialization.jsonObject(with: Data(try Self.coresFixture("TTY_NUMBERS").utf8)) as? [[Any]]
        )

        try #require(pairs.count == 5)
        for pair in pairs {
            let numbers = try #require(pair.first as? Int)

            #expect(device(of: dev_t(truncatingIfNeeded: numbers)) == pair.last as? String, "\(numbers)")
        }
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

        folder.file.write(Self.dimmed("sr-nw0001"), at: Self.at)

        #expect(try Data(contentsOf: folder.file.url) == HereFile.text(Self.dimmed("sr-nw0001"), at: Self.at))
        #expect(folder.names == [HereFile.name])
    }

    /// Written whole, beside the file then renamed over it: a reader holding the file open as it is written still
    /// reads the old whole, never the new one half written over it, and the next to open it reads the new whole.
    @Test func itIsWrittenWholeAReaderNeverSeesHalfAFile() throws {
        let folder = try Folder()
        let file = folder.file

        file.write(Self.dimmed("sr-nw0001"), at: Self.at)

        let reader = try FileHandle(forReadingFrom: file.url)

        defer { try? reader.close() }
        file.write(Self.dimmed("sr-ct0002", "sr-fb0004"), at: Self.at.addingTimeInterval(3))

        #expect(try reader.readToEnd() == HereFile.text(Self.dimmed("sr-nw0001"), at: Self.at))
        #expect(
            try Data(contentsOf: file.url) == HereFile.text(Self.dimmed("sr-ct0002", "sr-fb0004"), at: Self.at.addingTimeInterval(3))
        )
    }

    /// A write that fails makes nothing: into a board folder not there, which it never makes; and into one that is a
    /// file.
    @Test func aWriteThatFailsGoesNoFurther() throws {
        let folder = try Folder()
        let missing = folder.url.appending(path: "sitrep")
        let blocker = folder.url.appending(path: "blocked")

        HereFile(url: missing.appending(path: HereFile.name)).write(Self.dimmed("sr-nw0001"), at: Self.at)
        #expect(!FileManager.default.fileExists(atPath: missing.path))

        try Data("not a folder".utf8).write(to: blocker)
        HereFile(url: blocker.appending(path: HereFile.name)).write(Self.dimmed("sr-nw0001"), at: Self.at)
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
            file.write(Self.dimmed("sr-nw0001"), at: Self.at)
        }
        #expect(logged.withLock { $0.count } == 1)
        #expect(logged.withLock { $0.first?.hasPrefix("here.json was not written: ") } == true)

        try FileManager.default.createDirectory(at: board, withIntermediateDirectories: true)
        file.write(Self.dimmed("sr-nw0001"), at: Self.at)
        try FileManager.default.removeItem(at: board)
        file.write(Self.dimmed("sr-nw0001"), at: Self.at)
        file.write(Self.dimmed("sr-nw0001"), at: Self.at)
        #expect(logged.withLock { $0.count } == 2, "logged again only after a write succeeded")
    }

    /// Posted reads are written off the caller's thread, each in the order posted, so the last read stands.
    @Test func readsPostedAreWrittenInTurn() throws {
        let folder = try Folder()
        let file = folder.file

        for second in 0 ..< 10 {
            file.post(Self.dimmed("sr-nw000\(second)"), at: Self.at.addingTimeInterval(TimeInterval(second)))
        }
        file.flush()

        #expect(try Data(contentsOf: file.url) == HereFile.text(Self.dimmed("sr-nw0009"), at: Self.at.addingTimeInterval(9)))
    }

    /// A settling that changes what the file says writes it at once; one that changes nothing writes it again only once
    /// `refresh` has passed since the write that stands, either way, as a clock set back leaves it.
    @Test func aSettlingIsWrittenAtOnceOnAChangeAndOtherwiseEveryTenSeconds() throws {
        let folder = try Folder()
        let file = folder.file
        let phoned = Sightings(sessions: ["sr-nw0001": [Self.phone]])
        let attached = Sightings(sessions: ["sr-nw0001": [Self.phone]], ttys: ["/dev/ttys004": [Self.phone]])
        let posted = { (sightings: Sightings, seconds: TimeInterval) in
            file.post(sightings, at: Self.at.addingTimeInterval(seconds))
            file.flush()
            return try Data(contentsOf: file.url)
        }

        #expect(HereFile.refresh == 10)
        #expect(try posted(phoned, 0) == HereFile.text(phoned, at: Self.at))
        #expect(try posted(phoned, 9.999) == HereFile.text(phoned, at: Self.at), "the same, within 10 seconds")
        #expect(try posted(phoned, 10) == HereFile.text(phoned, at: Self.at.addingTimeInterval(10)), "10 seconds on")
        #expect(try posted(attached, 11) == HereFile.text(attached, at: Self.at.addingTimeInterval(11)), "a tty changed")
        #expect(try posted(phoned, 12) == HereFile.text(phoned, at: Self.at.addingTimeInterval(12)), "a session changed")
        #expect(try posted(phoned, 3) == HereFile.text(phoned, at: Self.at.addingTimeInterval(12)), "set back 9 seconds")
        #expect(try posted(phoned, 2) == HereFile.text(phoned, at: Self.at.addingTimeInterval(2)), "set back 10 seconds")
    }

    /// A write that failed is tried again at the next settling, though it changes nothing.
    @Test func aWriteThatFailedIsTriedAgainAtTheNextSettling() throws {
        let folder = try Folder()
        let board = folder.url.appending(path: "board")
        let file = HereFile(url: board.appending(path: HereFile.name)) { _ in }

        file.post(Self.dimmed("sr-nw0001"), at: Self.at)
        file.flush()
        try FileManager.default.createDirectory(at: board, withIntermediateDirectories: true)
        file.post(Self.dimmed("sr-nw0001"), at: Self.at.addingTimeInterval(3))
        file.flush()

        #expect(try Data(contentsOf: file.url) == HereFile.text(Self.dimmed("sr-nw0001"), at: Self.at.addingTimeInterval(3)))
    }

    /// A settling with no session read, as with nothing held, removes the file, a file left by a run before among it,
    /// once and in turn after the writes posted before it; more such settlings remove nothing, until a write, which the
    /// next settling makes at once.
    @Test func aSettlingWithNoSessionRemovesTheFileOnce() throws {
        let folder = try Folder()
        let file = folder.file
        let other = try HereFile.text(Self.dimmed("sr-ct0002"), at: Self.at)

        try other.write(to: file.url)
        file.post(Sightings(), at: Self.at)
        file.flush()
        #expect(folder.names.isEmpty, "a file left by a run before")

        try other.write(to: file.url)
        file.post(Sightings(), at: Self.at)
        file.flush()
        #expect(try Data(contentsOf: file.url) == other, "removed once: nothing more till a write")

        file.post(Self.dimmed("sr-nw0001"), at: Self.at)
        file.post(Sightings(), at: Self.at)
        file.flush()
        #expect(folder.names.isEmpty, "removed after the write posted before it")

        file.post(Self.dimmed("sr-nw0001"), at: Self.at.addingTimeInterval(1))
        file.flush()
        #expect(try Data(contentsOf: file.url) == HereFile.text(Self.dimmed("sr-nw0001"), at: Self.at.addingTimeInterval(1)))
    }

    /// Removed once every write posted before it is done, so none brings it back; removing a file not there says
    /// nothing.
    @Test func itIsRemovedAfterEveryWritePostedBeforeIt() throws {
        let folder = try Folder()
        let file = folder.file

        file.remove()
        for second in 0 ..< 10 {
            file.post(Self.dimmed("sr-nw0001"), at: Self.at.addingTimeInterval(TimeInterval(second)))
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

        file.write(Self.dimmed("sr-nw0001"), at: Self.at)
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
