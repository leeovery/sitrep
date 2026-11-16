import os
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// The continuous read of here, for the rows (stage 8's "How it is read" and "Where it can't tell"): at each line and
/// every few seconds, one read at a time; a session read as not here dimmed, one unknown keeping the look it last read,
/// one never read here, and none keeping a look past its hold.
@MainActor
struct HereWatchTests {
    /// A read the test answers: each read's sessions, by their windows, kept; held at the gate, where one is given,
    /// until the test opens it; answering as `answer` says at the time.
    private final class Reads: Sendable {
        private let state = OSAllocatedUnfairLock(
            initialState: (asked: [[String: [Where]]](), answer: [String: Here](), underWay: 0, most: 0)
        )
        private let gate: Gate?

        init(_ answer: [String: Here] = [:], gate: Gate? = nil) {
            self.gate = gate
            state.withLock { $0.answer = answer }
        }

        var asked: [[String: [Where]]] { state.withLock(\.asked) }
        /// The most reads under way at once.
        var most: Int { state.withLock(\.most) }

        func answer(_ answer: [String: Here]) {
            state.withLock { $0.answer = answer }
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
                    return state.answer.filter { sessions.keys.contains($0.key) }
                }
            }
        }
    }

    private static let unknown = Here.unknown([.tmux])

    /// A line whose windows hold the sessions given, each on a device of its own.
    private static func held(_ sessions: String...) throws -> Board {
        try board(sessions.enumerated().map { order, session in
            LineWindow(writer: "w-\(session)", session: session, order: order, device: "/dev/ttys0\(order + 10)")
        })
    }

    private static func watch(
        _ reads: Reads, clock: TestClock = TestClock(passing: .jumpsPauses),
        openings: RecentOpenings = RecentOpenings()
    ) -> HereWatch {
        HereWatch(openings: openings, clock: clock, read: reads.read)
    }

    /// Until the watch has made as many reads as given, and taken the last.
    private static func read(_ count: Int, by reads: Reads, of watch: HereWatch) async {
        await until(within: .seconds(10)) { reads.asked.count == count }
        await settle()
    }

    @Test func aSessionReadAsNotHereIsDimmedAndOneReadAsHereIsNot() async throws {
        let reads = Reads(["sr-a": .notHere, "sr-b": .here])
        let watch = Self.watch(reads)
        var changes: [Set<String>] = []

        watch.changed = { changes.append($0) }
        watch.heard(try Self.held("sr-a", "sr-b"))
        await Self.read(1, by: reads, of: watch)

        #expect(watch.notHere == ["sr-a"])
        #expect(changes == [["sr-a"]])
        #expect(reads.asked.first?["sr-a"] == [Where(device: "/dev/ttys010", terminal: "ghostty")])
        watch.stop()
    }

    /// Unknown is never taken for not here: a session keeps the look it last read, and one never read is here.
    @Test func anUnknownReadKeepsTheLastLookAndOneNeverReadIsHere() async throws {
        let reads = Reads(["sr-a": Self.unknown, "sr-b": .notHere])
        let watch = Self.watch(reads)
        let line = try Self.held("sr-a", "sr-b")

        watch.heard(line)
        await Self.read(1, by: reads, of: watch)
        #expect(watch.notHere == ["sr-b"], "sr-a, never read, is here")

        reads.answer(["sr-a": .notHere, "sr-b": Self.unknown])
        watch.heard(line)
        await Self.read(2, by: reads, of: watch)
        #expect(watch.notHere == ["sr-a", "sr-b"], "sr-b keeps not here")

        reads.answer(["sr-a": .here, "sr-b": .here])
        watch.heard(line)
        await Self.read(3, by: reads, of: watch)
        reads.answer(["sr-a": Self.unknown, "sr-b": Self.unknown])
        watch.heard(line)
        await Self.read(4, by: reads, of: watch)
        #expect(watch.notHere.isEmpty, "both keep here")
        watch.stop()
    }

    /// A session no window holds any more drops its look as the line comes, so it is never dimmed by a read from
    /// before, and a read under way as it goes gives it none.
    @Test func aSessionNoLongerHeldKeepsNoLookPastItsHold() async throws {
        let reads = Reads(["sr-a": .notHere, "sr-b": .notHere])
        let watch = Self.watch(reads)

        watch.heard(try Self.held("sr-a", "sr-b"))
        await Self.read(1, by: reads, of: watch)
        #expect(watch.notHere == ["sr-a", "sr-b"])

        watch.heard(try Self.held("sr-b"))
        #expect(watch.notHere == ["sr-b"], "dropped at the line, before any read")

        let gate = Gate()
        let held = Reads(["sr-a": .notHere], gate: gate)
        let racing = Self.watch(held)

        racing.heard(try Self.held("sr-a"))
        await until(within: .seconds(10)) { held.asked.count == 1 }
        racing.heard(try Self.held())
        gate.open()
        await settle()
        #expect(racing.notHere.isEmpty)
        #expect(held.asked.count == 1, "no session left to read")
        watch.stop()
        racing.stop()
    }

    /// One read at a time: lines during a read ask for one more, of the board as it then is; a tick during one asks
    /// none; and between lines it reads every `every`.
    @Test func itReadsOneAtATimeAtEachLineAndEveryFewSeconds() async throws {
        let gate = Gate()
        let clock = TestClock(passing: [])
        let reads = Reads(["sr-a": .notHere, "sr-b": .here], gate: gate)
        let watch = Self.watch(reads, clock: clock)

        watch.heard(try Self.held("sr-a"))
        await until(within: .seconds(10)) { reads.asked.count == 1 && clock.sleeps == [HereWatch.every] }
        watch.heard(try Self.held("sr-a"))
        watch.heard(try Self.held("sr-a", "sr-b"))
        clock.pass(HereWatch.every)
        await settle()
        #expect(reads.asked.count == 1)

        gate.open()
        await until(within: .seconds(10)) { reads.asked.count == 2 }
        await settle()
        #expect(reads.asked.last.map { Set($0.keys) } == ["sr-a", "sr-b"])
        #expect(reads.most == 1)

        await until(within: .seconds(10)) { clock.sleeps.count == 2 }
        clock.pass(HereWatch.every)
        await until(within: .seconds(10)) { reads.asked.count == 3 }
        #expect(HereWatch.every == .seconds(3))
        watch.stop()
    }

    /// A session read as here forgets the window opened for it, as a click reading it so does.
    @Test func aSessionReadAsHereForgetsItsOpening() async throws {
        let openings = RecentOpenings()
        let reads = Reads(["sr-a": .here, "sr-b": .notHere])
        let watch = Self.watch(reads, openings: openings)

        openings.remember("sr-a", wasHeld: true)
        openings.remember("sr-b", wasHeld: true)
        watch.heard(try Self.held("sr-a", "sr-b"))
        await Self.read(1, by: reads, of: watch)

        #expect(!openings.isOpening("sr-a"))
        #expect(openings.isOpening("sr-b"))
        watch.stop()
    }

    /// A line from a CLI before the watch carried each window's jump order or folder reads as any other.
    @Test func aLineFromAnOlderCLIReadsAsAnyOther() async throws {
        let reads = Reads(["sr-a": .notHere])
        let watch = Self.watch(reads)

        watch.heard(try board([LineWindow(writer: "w1", session: "sr-a", order: nil, device: "/dev/ttys010")]))
        await Self.read(1, by: reads, of: watch)

        #expect(reads.asked.first?["sr-a"] == [Where(device: "/dev/ttys010", terminal: "ghostty")])
        #expect(watch.notHere == ["sr-a"])
        watch.stop()
    }
}
