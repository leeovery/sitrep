import Darwin
import Foundation
import os
import Testing

extension Trait where Self == Backstop {
    /// The backstop, which every suite carries (`BackstopTests`).
    public static var backstop: Self {
        Backstop()
    }
}

/// Ends a run that has stopped going forward, rather than let it sit on a hung test for ever: each test case under the
/// trait is kept in flight from its start to its end (`InFlight`), and once no test has begun or ended for a while, with
/// some still in flight, the run is ended, failed, naming them, and the process groups their programs lead are killed
/// (`watchGroup(of:)`). SwiftPM runs each test target in a process of its own, so a run here is a target's. A hung test
/// cannot be failed and let go alone: Swift Testing lends a scope its body only for the length of the call, so the run
/// waits on the body however long it hangs.
///
/// It watches the run as a whole, never a test's own time: on a loaded Mac every test is slower, but tests go on
/// ending, so only a hang, which in the end leaves nothing else to end, a blocked main thread among them, trips it.
public struct Backstop: SuiteTrait, TestTrait, TestScoping {
    public var isRecursive: Bool { true }

    /// Each test case, never the suite as a whole.
    public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        testCase == nil ? nil : self
    }

    public func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        let flying = InFlight.shared.began(test.id.nameComponents.joined(separator: "/"))

        defer { InFlight.shared.ended(flying) }
        try await function()
    }
}

/// Watches the process group the leader leads, a test's program and every program it started: should the backstop end
/// the run, the group is killed with it. Until `endGroup(of:)`.
public func watchGroup(of leader: pid_t) {
    InFlight.shared.watch(group: leader)
}

/// Kills the process group the leader leads, with every program in it, as a test ends, and watches it no more.
public func endGroup(of leader: pid_t?) {
    if let leader {
        InFlight.shared.end(group: leader)
    }
}

/// The run's tests in flight and the process groups their programs lead, watched on a thread of its own: never one of
/// Swift's nor the main one, which a hang may hold.
final class InFlight: Sendable {
    static let shared = InFlight()

    /// How long the run may go with no test beginning or ending, while some are in flight, before it is ended. The
    /// longest any target's run went so was 89 seconds, measured with 20 burners on a Mac already at a load of 80 to 130
    /// (16 November 2026): SitRepTests' main actor, which most of its tests share, came round so seldom that none of
    /// them ended. At a load of 190, its main queue ran up to 122 seconds behind; a healthy test of 90 seconds, left
    /// running alone, is as quiet. Five minutes is well over twice the longest.
    static let quiet = Duration.seconds(300)
    /// How often the watch looks.
    private static let every: TimeInterval = 5

    private let flight = OSAllocatedUnfairLock(initialState: Flight(at: .now))

    private init() {
        Thread.detachNewThread { [self] in watch() }
    }

    func began(_ name: String) -> Int {
        flight.withLock { $0.begin(name, at: .now) }
    }

    func ended(_ test: Int) {
        flight.withLock { $0.end(test, at: .now) }
    }

    func watch(group leader: pid_t) {
        flight.withLock { _ = $0.groups.insert(leader) }
    }

    func end(group leader: pid_t) {
        flight.withLock { _ = $0.groups.remove(leader) }
        Self.kill(group: leader)
    }

    private func watch() {
        while true {
            Thread.sleep(forTimeInterval: Self.every)

            let (stall, groups) = flight.withLock { ($0.stall(at: .now, quiet: Self.quiet), $0.groups) }

            if let stall {
                Self.end(saying: stall, killing: groups)
            }
        }
    }

    /// Says why on stderr, after whatever Swift Testing has yet to write, kills the groups, and ends the process at
    /// once: its tests are hung, so there is nothing to wait on.
    private static func end(saying stall: String, killing groups: Set<pid_t>) -> Never {
        fflush(nil)
        FileHandle.standardError.write(Data(stall.utf8))
        groups.forEach { kill(group: $0) }
        fflush(nil)
        _exit(EXIT_FAILURE)
    }

    /// Never 0 nor 1, which would signal this process's own group, or every process Lee runs.
    private static func kill(group leader: pid_t) {
        if leader > 1 {
            Darwin.kill(-leader, SIGKILL)
        }
    }
}

/// The tests in flight, and when the run last went forward, a test beginning or ending; and the process groups their
/// programs lead. On the suspending clock, which stands still while the Mac sleeps, as the run does.
struct Flight {
    private struct Flying {
        let name: String
        let began: SuspendingClock.Instant
    }

    private var flying: [Int: Flying] = [:]
    private var given = 0
    private var moved: SuspendingClock.Instant
    var groups: Set<pid_t> = []

    init(at start: SuspendingClock.Instant) {
        moved = start
    }

    /// The test begun, by which it ends.
    mutating func begin(_ name: String, at now: SuspendingClock.Instant) -> Int {
        given += 1
        flying[given] = Flying(name: name, began: now)
        moved = now
        return given
    }

    mutating func end(_ test: Int, at now: SuspendingClock.Instant) {
        flying[test] = nil
        moved = now
    }

    /// Nil while the run goes forward: no test in flight, or one begun or ended within `quiet`. Otherwise, what the run
    /// is ended with: every test in flight, the longest first, and how long each has run.
    func stall(at now: SuspendingClock.Instant, quiet: Duration) -> String? {
        guard !flying.isEmpty, now - moved >= quiet else {
            return nil
        }

        let tests = flying.values.sorted { $0.began < $1.began }.map { "  \($0.name), \(Self.seconds(now - $0.began)) in\n" }

        return "The backstop ended the run: no test has begun or ended for \(Self.seconds(now - moved)). In flight:\n"
            + tests.joined()
    }

    private static func seconds(_ duration: Duration) -> String {
        "\(duration.components.seconds) s"
    }
}
