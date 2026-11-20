import Foundation
import os
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// The continuous read of here, for the rows (stage 8's "How it is read" and "Where it can't tell"): at each line and
/// every few seconds, one read at a time; a session read as not here dimmed, one unknown keeping the look it last read,
/// one never read here, and none keeping a look past its hold.
@MainActor
@Suite(.backstop)
struct HereWatchTests {
    /// A read the test answers: each read's sessions, by their windows, kept; held at the gate, where one is given,
    /// until the test opens it; answering as `answer` says at the time, the ttys with it.
    private final class Reads: Sendable {
        private let state = OSAllocatedUnfairLock(
            initialState: (
                asked: [[String: [Where]]](), answer: [String: Sighting](), ttys: [String: Set<Viewer>]?.some([:]),
                underWay: 0, most: 0
            )
        )
        private let gate: Gate?

        init(_ answer: [String: Sighting] = [:], ttys: [String: Set<Viewer>]? = [:], gate: Gate? = nil) {
            self.gate = gate
            self.answer(answer, ttys: ttys)
        }

        var asked: [[String: [Where]]] { state.withLock(\.asked) }
        /// The most reads under way at once.
        var most: Int { state.withLock(\.most) }

        func answer(_ answer: [String: Sighting], ttys: [String: Set<Viewer>]? = [:]) {
            state.withLock { state in
                state.answer = answer
                state.ttys = ttys
            }
        }

        var read: HereWatch.Read {
            { [self] sessions in
                state.withLock { state in
                    state.asked.append(sessions)
                    state.underWay += 1
                    state.most = max(state.most, state.underWay)
                }
                await gate?.pass()
                return state.withLock { state in
                    state.underWay -= 1
                    return HereRead(sessions: state.answer.filter { sessions.keys.contains($0.key) }, ttys: state.ttys)
                }
            }
        }
    }

    /// Seen on this Mac's screen; seen nowhere; seen only from Lee's phone over ssh; and not told.
    private static let here = Sighting.seen([.mac])
    private static let notHere = Sighting.seen([])
    private static let phone = Sighting.seen([.ssh(Mac.phone)])
    private static let unknown = Sighting.unknown([.tmux])

    /// A line whose windows hold the sessions given, each on a device of its own.
    private static func held(_ sessions: String...) throws -> Board {
        try board(sessions.enumerated().map { order, session in
            WatchLine.Window.jumping("w-\(session)", session: session, order: order, device: "/dev/ttys0\(order + 10)")
        })
    }

    private static func watch(
        _ reads: Reads, clock: TestClock = TestClock(passing: .jumpsPauses),
        openings: RecentOpenings = RecentOpenings()
    ) -> HereWatch {
        HereWatch(openings: openings, clock: clock, read: reads.read)
    }

    /// Until the watch has made as many reads as given, and taken the last.
    private static func read(_ count: Int, by reads: Reads, of watch: HereWatch) async throws {
        try await until(within: .seconds(10), "for read \(count) to be made and taken") {
            reads.asked.count == count && watch.reading == nil
        }
    }

    @Test func aSessionReadAsNotHereIsDimmedAndOneReadAsHereIsNot() async throws {
        let reads = Reads(["sr-a": Self.notHere, "sr-b": Self.here])
        let watch = Self.watch(reads)
        var changes: [Set<String>] = []

        defer { watch.stop() }
        watch.changed = { changes.append($0) }
        watch.heard(try Self.held("sr-a", "sr-b"))
        try await Self.read(1, by: reads, of: watch)

        #expect(watch.notHere == ["sr-a"])
        #expect(changes == [["sr-a"]])
        #expect(reads.asked.first?["sr-a"] == [Where(device: "/dev/ttys010", terminal: "ghostty")])
    }

    /// Unknown is never taken for not here: a session keeps the look it last read, and one never read is here.
    @Test func anUnknownReadKeepsTheLastLookAndOneNeverReadIsHere() async throws {
        let reads = Reads(["sr-a": Self.unknown, "sr-b": Self.notHere])
        let watch = Self.watch(reads)
        let line = try Self.held("sr-a", "sr-b")

        defer { watch.stop() }
        watch.heard(line)
        try await Self.read(1, by: reads, of: watch)
        #expect(watch.notHere == ["sr-b"], "sr-a, never read, is here")

        reads.answer(["sr-a": Self.notHere, "sr-b": Self.unknown])
        watch.heard(line)
        try await Self.read(2, by: reads, of: watch)
        #expect(watch.notHere == ["sr-a", "sr-b"], "sr-b keeps not here")

        reads.answer(["sr-a": Self.here, "sr-b": Self.here])
        watch.heard(line)
        try await Self.read(3, by: reads, of: watch)
        reads.answer(["sr-a": Self.unknown, "sr-b": Self.unknown])
        watch.heard(line)
        try await Self.read(4, by: reads, of: watch)
        #expect(watch.notHere.isEmpty, "both keep here")
    }

    /// A session no window holds any more drops its look as the line comes, so it is never dimmed by a read from
    /// before, and a read under way as it goes gives it none.
    @Test func aSessionNoLongerHeldKeepsNoLookPastItsHold() async throws {
        let reads = Reads(["sr-a": Self.notHere, "sr-b": Self.notHere])
        let watch = Self.watch(reads)

        defer { watch.stop() }
        watch.heard(try Self.held("sr-a", "sr-b"))
        try await Self.read(1, by: reads, of: watch)
        #expect(watch.notHere == ["sr-a", "sr-b"])

        watch.heard(try Self.held("sr-b"))
        #expect(watch.notHere == ["sr-b"], "dropped at the line, before any read")

        let gate = Gate()
        let held = Reads(["sr-a": Self.notHere], gate: gate)
        let racing = Self.watch(held)

        defer { racing.stop() }
        racing.heard(try Self.held("sr-a"))
        try await until(within: .seconds(10)) { held.asked.count == 1 }
        racing.heard(try Self.held())
        gate.open()
        try await until(within: .seconds(10)) { racing.reading == nil }
        #expect(racing.notHere.isEmpty)
        #expect(held.asked.count == 1, "no session left to read")
    }

    /// One read at a time: lines during a read ask for one more, of the board as it then is; a tick during one asks
    /// none; and between lines it reads every `every`.
    @Test func itReadsOneAtATimeAtEachLineAndEveryFewSeconds() async throws {
        let gate = Gate()
        let clock = TestClock(passing: [])
        let reads = Reads(["sr-a": Self.notHere, "sr-b": Self.here], gate: gate)
        let watch = Self.watch(reads, clock: clock)

        defer { watch.stop() }
        watch.heard(try Self.held("sr-a"))
        try await until(within: .seconds(10)) { reads.asked.count == 1 && clock.sleeps == [HereWatch.every] }

        let first = try #require(watch.reading)

        watch.heard(try Self.held("sr-a"))
        watch.heard(try Self.held("sr-a", "sr-b"))
        clock.pass(HereWatch.every)
        try await until(within: .seconds(10)) { clock.sleeps.count == 2 }
        #expect(watch.reading == first, "the tick, its next sleep begun, began no read")
        #expect(reads.asked.count == 1)

        gate.open()
        try await Self.read(2, by: reads, of: watch)
        #expect(reads.asked.last.map { Set($0.keys) } == ["sr-a", "sr-b"])
        #expect(reads.most == 1)

        clock.pass(HereWatch.every)
        try await until(within: .seconds(10)) { reads.asked.count == 3 }
        #expect(HereWatch.every == .seconds(3))
    }

    /// The sightings in words, each session in order with its viewers in order, then each tty with its.
    private static func words(_ sightings: Sightings) -> String {
        let each = { (map: [String: Set<Viewer>]) in
            map.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value.map(\.text).sorted())" }
        }

        return (each(sightings.sessions) + each(sightings.ttys)).joined(separator: ", ")
    }

    /// Each settling is told, changed or not, after `changed` where `notHere` changed: at each read, and at each line,
    /// which drops a session no window holds with no read.
    @Test func eachSettlingIsToldChangedOrNot() async throws {
        let reads = Reads(["sr-a": Self.notHere, "sr-b": Self.here])
        let watch = Self.watch(reads)
        let line = try Self.held("sr-a", "sr-b")
        var told: [String] = []

        defer { watch.stop() }
        watch.changed = { told.append("changed \($0.sorted())") }
        watch.settled = { told.append("settled \(Self.words($0))") }
        watch.heard(line)
        try await Self.read(1, by: reads, of: watch)
        watch.heard(line)
        try await Self.read(2, by: reads, of: watch)
        watch.heard(try Self.held())

        let both = #"settled sr-a [], sr-b ["mac"]"#

        #expect(told == ["settled ", #"changed ["sr-a"]"#, both, both, both, "changed []", "settled "])
        #expect(reads.asked.count == 2, "the last line read nothing")
    }

    /// The viewers of each session, its own tty's among them, as last read: one read as unknown keeps its viewers, one
    /// open only on Lee's phone among them, and one never read has none; the ttys each read gives, kept where its
    /// table gave no answer.
    @Test func eachSessionKeepsItsViewersAsLastReadAndEachReadItsTtys() async throws {
        let ttys: [String: Set<Viewer>] = ["/dev/ttys050": [.ssh(Mac.phone)]]
        let reads = Reads(["sr-a": Self.phone, "sr-b": Self.unknown], ttys: ttys)
        let watch = Self.watch(reads)
        let line = try Self.held("sr-a", "sr-b")

        defer { watch.stop() }
        watch.heard(line)
        try await Self.read(1, by: reads, of: watch)
        #expect(watch.sightings == Sightings(sessions: ["sr-a": [.ssh(Mac.phone)]], ttys: ttys), "sr-b never read")

        reads.answer(["sr-a": Self.unknown, "sr-b": Self.here], ttys: nil)
        watch.heard(line)
        try await Self.read(2, by: reads, of: watch)
        #expect(watch.sightings == Sightings(sessions: ["sr-a": [.ssh(Mac.phone)], "sr-b": [.mac]], ttys: ttys))

        reads.answer(["sr-a": Self.notHere, "sr-b": Self.here], ttys: [:])
        watch.heard(line)
        try await Self.read(3, by: reads, of: watch)
        #expect(watch.sightings == Sightings(sessions: ["sr-a": [], "sr-b": [.mac]]))
    }

    /// The notch's dimmed as before: the sessions read whose viewers hold no `mac`, one open only on Lee's phone among
    /// them, as no terminal on this Mac shows it; one on this Mac's screen and the phone's not.
    @Test func notHereIsTheSessionsReadWhoseViewersHoldNoMac() async throws {
        let both = Sighting.seen([.mac, .ssh(Mac.phone)])
        let reads = Reads(["sr-a": Self.phone, "sr-b": both, "sr-c": Self.notHere, "sr-d": Self.unknown])
        let watch = Self.watch(reads)

        defer { watch.stop() }
        watch.heard(try Self.held("sr-a", "sr-b", "sr-c", "sr-d"))
        try await Self.read(1, by: reads, of: watch)

        #expect(watch.notHere == ["sr-a", "sr-c"])
        #expect(Sightings(sessions: ["sr-a": [.ssh(Mac.phone)], "sr-b": [.mac], "sr-c": []]).notHere == ["sr-a", "sr-c"])
    }

    /// As the app keeps it (`writes(to:)`): `here.json` written at the first read, its time the settling's own; not
    /// written again by reads that change nothing within `HereFile.refresh`; removed at once as a line drops the
    /// session; and written while any session is held, though none is dimmed.
    @Test func hereJsonIsKeptInStepWithEachSettling() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "sitrep-here-\(UUID().uuidString)")
        let file = HereFile(url: folder.appending(path: HereFile.name))
        let ttys: [String: Set<Viewer>] = ["/dev/ttys050": [.ssh(Mac.phone)]]
        let reads = Reads(["sr-a": Self.phone, "sr-b": Self.here], ttys: ttys)
        let watch = Self.watch(reads)
        let line = try Self.held("sr-a")
        var stamped: [Date] = []

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            watch.stop()
            try? FileManager.default.removeItem(at: folder)
        }
        watch.writes(to: file) {
            stamped.append(Date(timeIntervalSince1970: 1_763_650_000 + 3 * Double(stamped.count)))
            return stamped[stamped.count - 1]
        }
        watch.heard(line)
        try await Self.read(1, by: reads, of: watch)
        file.flush()

        let first = try HereFile.text(Sightings(sessions: ["sr-a": [.ssh(Mac.phone)]], ttys: ttys), at: stamped[stamped.count - 1])

        #expect(try Data(contentsOf: file.url) == first)

        watch.heard(line)
        try await Self.read(2, by: reads, of: watch)
        file.flush()
        #expect(try Data(contentsOf: file.url) == first, "the same, 6 seconds on")

        watch.heard(try Self.held())
        file.flush()
        #expect(!FileManager.default.fileExists(atPath: file.url.path), "dropped by the line, no read")

        watch.heard(try Self.held("sr-b"))
        try await Self.read(3, by: reads, of: watch)
        file.flush()
        #expect(
            try Data(contentsOf: file.url)
                == HereFile.text(Sightings(sessions: ["sr-b": [.mac]], ttys: ttys), at: stamped[stamped.count - 1]),
            "nothing dimmed, and written"
        )
    }

    /// A session read as here forgets the window opened for it, as a click reading it so does.
    @Test func aSessionReadAsHereForgetsItsOpening() async throws {
        let openings = RecentOpenings()
        let reads = Reads(["sr-a": Self.here, "sr-b": Self.notHere])
        let watch = Self.watch(reads, openings: openings)

        defer { watch.stop() }
        openings.remember("sr-a", wasHeld: true)
        openings.remember("sr-b", wasHeld: true)
        watch.heard(try Self.held("sr-a", "sr-b"))
        try await Self.read(1, by: reads, of: watch)

        #expect(!openings.isOpening("sr-a"))
        #expect(openings.isOpening("sr-b"))
    }

    /// A line from a CLI before the watch carried each window's jump order or folder reads as any other.
    @Test func aLineFromAnOlderCLIReadsAsAnyOther() async throws {
        let reads = Reads(["sr-a": Self.notHere])
        let watch = Self.watch(reads)

        defer { watch.stop() }
        watch.heard(try board([WatchLine.Window.jumping("w1", session: "sr-a", order: nil, device: "/dev/ttys010")]))
        try await Self.read(1, by: reads, of: watch)

        #expect(reads.asked.first?["sr-a"] == [Where(device: "/dev/ttys010", terminal: "ghostty")])
        #expect(watch.notHere == ["sr-a"])
    }
}
