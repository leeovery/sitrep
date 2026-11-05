import Foundation
@testable import SitRepCore
import os
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SitRepWatchTests {
    private static let path = "/Users/lee/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"

    /// The watch over the runs given, on their clock, Lee's PATH taking as long as given to find, and held back by the
    /// gate given, if one is.
    private static func watch(
        _ runs: Runs, pathTakes: Duration = .zero, pathWaitsOn gate: Gate? = nil
    ) -> SitRepWatch<TestClock> {
        let clock = runs.clock
        let cli = SitRepCLI(plugin: URL(fileURLWithPath: "/Users/lee/Code/sitrep"), path: {
            await gate?.wait()
            clock.advance(by: pathTakes)

            return path
        }, environment: ["HOME": "/Users/lee"])

        return SitRepWatch(cli: cli, watcher: runs.watcher, clock: clock, now: { clock.date })
    }

    /// The first boards the watch publishes, each heard as given; the reading stops after them.
    private static func boards(
        _ count: Int, of runs: Runs, pathTakes: Duration = .zero, hearing: (LastBoard) -> Void = { _ in }
    ) async -> [LastBoard] {
        var boards: [LastBoard] = []

        for await board in watch(runs, pathTakes: pathTakes).boards() {
            boards.append(board)
            hearing(board)

            if boards.count == count {
                break
            }
        }

        return boards
    }

    private static func exited(_ status: Int32, lives: Duration = .zero) -> Run {
        Run(lives: lives, says: [.exited(.status(status), stderr: "")])
    }

    private static let watching = Run(says: [.line(watched)], ends: false)

    @Test func itRunsThePluginsWatchWithLeesPathAndNoTimeLimit() async {
        let runs = Runs([Self.watching])

        _ = await Self.boards(1, of: runs)

        #expect(runs.programs == [
            Program(
                executable: URL(fileURLWithPath: "/Users/lee/Code/sitrep/bin/sitrep"),
                arguments: ["watch"],
                environment: ["HOME": "/Users/lee", "PATH": Self.path],
                limit: .infinity,
                stopping: .group
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

    @Test func whenWatchEndsTheBoardIsKeptStaleSinceThenAndWatchStartsAgainASecondLater() async throws {
        let runs = Runs([
            Run(lives: .seconds(5), says: [.line(watched), .exited(.status(1), stderr: "sitrep: the state folder went\n")]),
            Run(says: [.line(watchedEmpty)], ends: false),
        ])

        let boards = await Self.boards(3, of: runs)

        #expect(boards.map(\.board) == [try Board.read(watched), try Board.read(watched), try Board.read(watchedEmpty)])
        #expect(boards.map(\.stale) == [nil, .exited(.status(1), said: "the state folder went"), nil])
        #expect(boards.map(\.staleSince) == [nil, TestClock.date(at: .seconds(5)), nil])
        #expect(runs.clock.slept == [.seconds(1)])
        #expect(runs.programs.count == 2)
    }

    /// `Feed` starting a watch again while the last waits on Lee's PATH, as it may as SitRep settles on a plugin: the
    /// last, stopped, resumes after the next began, and begins no run of its own.
    @Test func aWatchStoppedWhileItWaitsOnLeesPathBeginsNoRun() async {
        let gate = Gate()
        let stopped = Runs([Self.watching])
        let next = Runs([Self.watching])
        let first = Task {
            for await _ in Self.watch(stopped, pathWaitsOn: gate).boards() {}
        }

        await gate.asked()
        first.cancel()

        let (heard, hearing) = AsyncStream<Void>.makeStream()
        let running = Task {
            for await _ in Self.watch(next).boards() {
                hearing.yield()
            }
        }

        for await _ in heard {
            break
        }
        gate.open()
        // Nothing tells when the stopped watch's loop has run on past its PATH, as it begins nothing: one that began a
        // run would within this, and one that begins none passes, however long the wait.
        try? await Task.sleep(for: .milliseconds(200))
        running.cancel()
        #expect(next.programs.count == 1)
        #expect(stopped.programs.isEmpty)
    }

    @Test func watchThatCannotStartIsTriedAgain() async {
        let runs = Runs([Run(says: [.unstartable("no such file")]), Self.watching])

        let boards = await Self.boards(2, of: runs)

        #expect(boards.map(\.stale) == [.unstartable("no such file"), nil])
    }

    @Test func eachEndInARowWaitsLongerAndARunThatLivedAMinuteStartsTheCountAgain() async {
        let runs = Runs((1...4).map { Self.exited($0) } + [Self.exited(5, lives: .seconds(60)), Self.exited(6)])

        _ = await Self.boards(6, of: runs)

        #expect(Array(runs.clock.slept.prefix(5)) == [1, 2, 4, 8, 1].map { .seconds($0) })
    }

    @Test func watchMakingWayForANewVersionIsStartedAgainAtOnceTheBoardNotStale() async throws {
        let runs = Runs([
            Run(lives: .seconds(1), says: [.line(watched), .exited(.status(0), stderr: "")]),
            Run(says: [.line(watchedEmpty)], ends: false),
        ])

        let boards = await Self.boards(2, of: runs)

        #expect(boards.map(\.board) == [try Board.read(watched), try Board.read(watchedEmpty)])
        #expect(boards.map(\.stale) == [nil, nil])
        #expect(runs.clock.slept == [])
        #expect(runs.programs.count == 2)
    }

    @Test func makingWayForANewVersionStartsTheBackOffAgain() async {
        let runs = Runs([Self.exited(1), Self.exited(2), Self.exited(0, lives: .seconds(5)), Self.exited(3), Self.watching])

        _ = await Self.boards(4, of: runs)

        #expect(runs.clock.slept == [1, 2, 1].map { .seconds($0) })
    }

    @Test func watchExiting0WithinASecondOfStartingIsAFailure() async throws {
        let runs = Runs([
            Run(lives: .milliseconds(500), says: [.line(watched), .exited(.status(0), stderr: "")]),
            Run(says: [.line(watchedEmpty)], ends: false),
        ])

        let boards = await Self.boards(3, of: runs)

        #expect(boards.map(\.stale) == [nil, .exited(.status(0), said: nil), nil])
        #expect(boards[1].board == (try Board.read(watched)))
        #expect(runs.clock.slept == [.seconds(1)])
    }

    @Test func findingLeesPathIsNotCountedInARunsLife() async {
        let runs = Runs([Self.exited(0), Self.watching])

        let boards = await Self.boards(2, of: runs, pathTakes: .seconds(10))

        #expect(boards.first?.stale == .exited(.status(0), said: nil))
        #expect(runs.clock.slept == [.seconds(1)])
    }

    @Test func aRenewalWithinAMinuteOfTheLastIsAFailure() async {
        let runs = Runs([Self.exited(0, lives: .seconds(30)), Self.exited(0, lives: .seconds(59)), Self.watching])

        let boards = await Self.boards(2, of: runs)

        #expect(boards.first?.stale == .exited(.status(0), said: nil))
        #expect(runs.clock.slept == [.seconds(1)])
    }

    @Test func aRenewalAMinuteAfterTheLastIsARenewal() async {
        let runs = Runs([Self.exited(0, lives: .seconds(30)), Self.exited(0, lives: .seconds(60)), Self.watching])

        let boards = await Self.boards(1, of: runs)

        #expect(boards.first?.stale == nil)
        #expect(runs.clock.slept == [])
        #expect(runs.programs.count == 3)
    }

    @Test func readingNoMoreStopsWatch() async {
        let runs = Runs([Self.watching])

        _ = await Self.boards(1, of: runs)
        await runs.stopped()

        #expect(runs.programs.count == 1)
    }
}

/// A run of `watch` stood in for: as it is read, it lives as long as given
/// on the test clock, says what is given, and ends, unless it is one that
/// never ends until it is stopped.
private struct Run {
    var lives: Duration = .zero
    var says: [Heard]
    var ends = true
}

/// `watch` run as the script gives, a run each time it is started; once the
/// script runs out, a run says nothing and never ends.
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
            let left = OSAllocatedUnfairLock(initialState: (lives: run.lives, says: run.says))

            return AsyncStream { [clock, stop] in
                let (lives, said) = left.withLock { left in
                    defer { left = (.zero, Array(left.says.dropFirst())) }

                    return (left.lives, left.says.first)
                }

                clock.advance(by: lives)

                if let said {
                    return said
                }

                if !run.ends {
                    try? await Task.sleep(for: .seconds(3600))
                    stop.yield()
                }

                return nil
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

/// Lee's PATH held back until the test lets it go, as a login shell slow to answer holds it, deaf to cancellation as
/// that ask is.
private final class Gate: Sendable {
    private let waiting = OSAllocatedUnfairLock<CheckedContinuation<Void, Never>?>(initialState: nil)
    private let (asking, isAsked) = AsyncStream<Void>.makeStream()

    func wait() async {
        await withCheckedContinuation { waiting in
            self.waiting.withLock { $0 = waiting }
            isAsked.yield()
        }
    }

    /// Once the PATH has been asked for.
    func asked() async {
        for await _ in asking {
            return
        }
    }

    func open() {
        waiting.withLock { waiting in
            waiting?.resume()
            waiting = nil
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

    /// The time of day as the clock starts.
    private static let start = Date(timeIntervalSince1970: 1_792_445_600)

    private let state = OSAllocatedUnfairLock(initialState: (now: Duration.zero, slept: [Duration]()))

    var now: Instant { Instant(offset: state.withLock { $0.now }) }
    var minimumResolution: Duration { .zero }
    var slept: [Duration] { state.withLock { $0.slept } }

    /// The time of day as the clock stands.
    var date: Date { Self.date(at: now.offset) }

    static func date(at offset: Duration) -> Date {
        start.addingTimeInterval(Double(offset.components.seconds) + Double(offset.components.attoseconds) / 1e18)
    }

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
