import Foundation
@testable import SitRepCore
import os
import Testing

struct SitRepWatchTests {
    private static let path = "/Users/lee/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"

    /// The watch over the runs given, on their clock.
    private static func watch(_ runs: Runs) -> SitRepWatch<TestClock> {
        let cli = SitRepCLI(plugin: URL(fileURLWithPath: "/Users/lee/Code/sitrep"), path: { path }, environment: ["HOME": "/Users/lee"])

        return SitRepWatch(cli: cli, watcher: runs.watcher, clock: runs.clock)
    }

    /// The first boards the watch publishes; the reading stops after them.
    private static func boards(_ count: Int, of runs: Runs) async -> [LastBoard] {
        var boards: [LastBoard] = []

        for await board in watch(runs).boards() {
            boards.append(board)

            if boards.count == count {
                break
            }
        }

        return boards
    }

    @Test func itRunsThePluginsWatchWithLeesPathAndNoTimeLimit() async {
        let runs = Runs([Run(says: [.line(watched)], ends: false)])

        _ = await Self.boards(1, of: runs)

        #expect(runs.programs == [
            Program(
                executable: URL(fileURLWithPath: "/Users/lee/Code/sitrep/bin/sitrep"),
                arguments: ["watch"],
                environment: ["HOME": "/Users/lee", "PATH": Self.path],
                limit: .infinity
            ),
        ])
    }

    @Test func eachLineIsABoardAsItIsHeard() async throws {
        let runs = Runs([Run(says: [.line(watchedEmpty), .line(watched)], ends: false)])

        let boards = await Self.boards(2, of: runs)

        #expect(boards.map(\.board) == [try Board.read(watchedEmpty), try Board.read(watched)])
        #expect(boards.map(\.stale) == [nil, nil])
    }

    @Test func aLineThatDoesNotReadIsSkippedAndWatchRunsOn() async throws {
        let runs = Runs([Run(says: [.line(watched), .line("{"), .line(watchedEmpty)], ends: false)])

        let boards = await Self.boards(3, of: runs)

        #expect(boards.last?.board == (try Board.read(watchedEmpty)))
        #expect(boards.last?.stale == nil)
        #expect(runs.programs.count == 1)
    }

    @Test func whenWatchEndsTheBoardIsKeptStaleAndWatchStartsAgainASecondLater() async throws {
        let runs = Runs([
            Run(says: [.line(watched), .exited(status: 1, stderr: "sitrep: the state folder went\n")]),
            Run(says: [.line(watchedEmpty)], ends: false),
        ])

        let boards = await Self.boards(3, of: runs)

        #expect(boards.map(\.board) == [try Board.read(watched), try Board.read(watched), try Board.read(watchedEmpty)])
        #expect(boards.map(\.stale) == [nil, .exited(status: 1, said: "the state folder went"), nil])
        #expect(runs.clock.slept == [.seconds(1)])
        #expect(runs.programs.count == 2)
    }

    @Test func watchThatCannotStartIsTriedAgain() async {
        let runs = Runs([Run(says: [.unstartable("no such file")]), Run(says: [.line(watched)], ends: false)])

        let boards = await Self.boards(2, of: runs)

        #expect(boards.map(\.stale) == [.unstartable("no such file"), nil])
    }

    @Test func eachEndInARowWaitsLongerAndARunThatLivedAMinuteStartsTheCountAgain() async {
        let ends = (1...4).map { Run(says: [.exited(status: $0, stderr: "")]) }
        let lived = Run(lives: .seconds(60), says: [.exited(status: 5, stderr: "")])
        let runs = Runs(ends + [lived, Run(says: [.exited(status: 6, stderr: "")])])

        _ = await Self.boards(6, of: runs)

        #expect(Array(runs.clock.slept.prefix(5)) == [1, 2, 4, 8, 1].map { .seconds($0) })
    }

    @Test func watchMakingWayForANewVersionIsStartedAgainAtOnceTheBoardNotStale() async throws {
        let runs = Runs([
            Run(lives: .seconds(1), says: [.line(watched), .exited(status: 0, stderr: "")]),
            Run(says: [.line(watchedEmpty)], ends: false),
        ])

        let boards = await Self.boards(2, of: runs)

        #expect(boards.map(\.board) == [try Board.read(watched), try Board.read(watchedEmpty)])
        #expect(boards.map(\.stale) == [nil, nil])
        #expect(runs.clock.slept == [])
        #expect(runs.programs.count == 2)
    }

    @Test func makingWayForANewVersionStartsTheBackOffAgain() async {
        let runs = Runs([
            Run(says: [.exited(status: 1, stderr: "")]),
            Run(says: [.exited(status: 2, stderr: "")]),
            Run(lives: .seconds(5), says: [.exited(status: 0, stderr: "")]),
            Run(says: [.exited(status: 3, stderr: "")]),
            Run(says: [.line(watched)], ends: false),
        ])

        _ = await Self.boards(4, of: runs)

        #expect(runs.clock.slept == [1, 2, 1].map { .seconds($0) })
    }

    @Test func watchExiting0WithinASecondOfStartingIsAFailure() async throws {
        let runs = Runs([
            Run(lives: .milliseconds(500), says: [.line(watched), .exited(status: 0, stderr: "")]),
            Run(says: [.line(watchedEmpty)], ends: false),
        ])

        let boards = await Self.boards(3, of: runs)

        #expect(boards.map(\.stale) == [nil, .exited(status: 0, said: nil), nil])
        #expect(boards[1].board == (try Board.read(watched)))
        #expect(runs.clock.slept == [.seconds(1)])
    }

    @Test func readingNoMoreStopsWatch() async {
        let runs = Runs([Run(says: [.line(watched)], ends: false)])

        _ = await Self.boards(1, of: runs)
        await runs.stopped()

        #expect(runs.programs.count == 1)
    }
}

/// A run of `watch` stood in for: it lives as long as given on the test
/// clock, says what is given, and ends, unless it is one that never ends
/// until it is stopped.
private struct Run {
    var lives: Duration = .zero
    var says: [Heard]
    var ends = true
}

/// `watch` run as the script gives, a run each time it is started; once
/// the script runs out, a run says nothing and never ends.
private final class Runs: Sendable {
    let clock = TestClock()

    private let script: OSAllocatedUnfairLock<[Run]>
    private let started = OSAllocatedUnfairLock<[Program]>(initialState: [])
    private let stops: AsyncStream<Void>
    private let stop: AsyncStream<Void>.Continuation

    init(_ script: [Run]) {
        self.script = OSAllocatedUnfairLock(initialState: script)
        (stops, stop) = AsyncStream.makeStream()
    }

    var programs: [Program] { started.withLock { $0 } }

    var watcher: Watcher {
        { [self] program in
            started.withLock { $0.append(program) }

            let run = script.withLock { $0.isEmpty ? Run(says: [], ends: false) : $0.removeFirst() }

            return AsyncStream { heard in
                clock.advance(by: run.lives)
                run.says.forEach { heard.yield($0) }

                if run.ends {
                    heard.finish()
                } else {
                    heard.onTermination = { [stop] _ in stop.yield() }
                }
            }
        }
    }

    /// Once a run that never ends is stopped.
    func stopped() async {
        for await _ in stops {
            return
        }
    }
}

/// A clock that moves only as it is told to or slept on, each sleep kept.
private final class TestClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        let offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (left: Instant, right: Instant) -> Bool { left.offset < right.offset }
    }

    private let state = OSAllocatedUnfairLock(initialState: (now: Duration.zero, slept: [Duration]()))

    var now: Instant { Instant(offset: state.withLock { $0.now }) }
    var minimumResolution: Duration { .zero }
    var slept: [Duration] { state.withLock { $0.slept } }

    func advance(by duration: Duration) {
        state.withLock { $0.now += duration }
    }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
        state.withLock { state in
            state.slept.append(deadline.offset - state.now)
            state.now = deadline.offset
        }
    }
}
