import Darwin
import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// Real programs run, each as a child of the test's. Every wait on one is bounded, and every child a program leaves is
/// learnt through a handshake and killed however the test ends, so a run that never ends fails its test and leaves
/// nothing behind.
@Suite(.timeLimit(.minutes(1)))
struct RunTests {
    private static func sh(
        _ script: String, environment: [String: String] = [:], limit: TimeInterval = 5, stopping: Stopping = .alone
    ) -> Program {
        Program(
            executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], environment: environment,
            limit: limit, stopping: stopping
        )
    }

    /// How the run ended, or nil, failing the test, where it had not within the time.
    private static func ran(
        _ program: Program, within limit: Duration = .seconds(20), sourceLocation: SourceLocation = #_sourceLocation
    ) async -> Result<Ran, any Error>? {
        await result(of: Task { try await runProgram(program) }, within: limit, sourceLocation: sourceLocation)
    }

    @Test(.tags(.process))
    func aRunGivesTheExitStatusAndBothOutputs() async throws {
        let ran = try await Self.ran(Self.sh("echo out; echo err >&2; exit 3"))?.get()

        #expect(ran == Ran(status: 3, stdout: "out\n", stderr: "err\n"))
    }

    @Test(.tags(.process))
    func theProgramGetsOnlyTheEnvironmentGiven() async throws {
        let ran = try await Self.ran(
            Self.sh(#"printf '%s|%s' "$PATH" "${HOME-unset}""#, environment: ["PATH": "/lee/bin"])
        )?.get()

        #expect(ran?.stdout == "/lee/bin|unset")
    }

    @Test(.tags(.process))
    func stdinIsEmpty() async throws {
        let ran = try await Self.ran(Self.sh("cat; echo read"))?.get()

        #expect(ran?.stdout == "read\n")
    }

    @Test(.tags(.process))
    func outputLargerThanAPipeHoldsIsReadWhole() async throws {
        let ran = try await Self.ran(Self.sh("head -c 200000 /dev/zero | tr '\\0' x"))?.get()

        #expect(ran?.stdout.count == 200_000)
    }

    @Test(.tags(.process))
    func aProgramThatCannotStartIsUnstartable() async throws {
        let missing = Program(executable: URL(fileURLWithPath: "/no/such/sitrep"), arguments: [], environment: [:], limit: 5)
        let ran = try #require(await Self.ran(missing))

        #expect {
            try ran.get()
        } throws: { error in
            if case .unstartable = error as? RunError { true } else { false }
        }
    }

    /// Killed at its limit, well before its own end: never killed, it would end of itself ten seconds on, and the run
    /// would still be waiting on it at its five.
    @Test(.tags(.process))
    func aProgramOutlivingItsLimitIsKilledAndTimedOut() async throws {
        let ran = try #require(await Self.ran(Self.sh("sleep 10", limit: 0.3), within: .seconds(5)))

        #expect(throws: RunError.timedOut(0.3)) { try ran.get() }
    }

    /// An interactive shell ignores SIGTERM, so the kill must be one it cannot ignore. Stopped as its task is
    /// cancelled, which ends it as its limit does, once it says it has set its trap.
    @Test(.tags(.process))
    func aProgramIgnoringTermIsKilledAllTheSame() async throws {
        let ready = try Handshake()
        let program = Self.sh("trap '' TERM; echo $$ > '\(ready.path)'; while :; do sleep 1; done", limit: 60)
        let run = Task { try await runProgram(program) }
        let trapping = await ready.line().flatMap { pid_t($0) }

        defer { Self.end(run, trapping) }
        let shell = try #require(trapping)

        run.cancel()
        let stopped = try #require(await result(of: run, within: .seconds(5)))

        #expect(throws: RunError.stopped) { try stopped.get() }
        #expect(await Self.isGone(shell))
    }

    /// The run ends as the program does, its output read only to the drain's half second: the child it left, holding
    /// that output open, would hold the run to the child's end, an hour on, where the drain was not cut.
    @Test(.tags(.process))
    func aChildLeftHoldingTheOutputOpenIsNotWaitedOn() async throws {
        let ready = try Handshake()
        let program = Self.sh("echo done; sleep 3600 & echo $! > '\(ready.path)'", limit: 20)
        let run = Task { try await runProgram(program) }
        let left = await ready.line().flatMap { pid_t($0) }

        defer { Self.end(run, left) }
        let ran = try #require(await result(of: run, within: .seconds(5)))

        #expect(try ran.get() == Ran(status: 0, stdout: "done\n", stderr: ""))
    }

    @Test func timingOutIsToldInWords() {
        #expect(RunError.timedOut(30).description == "did not answer within 30 seconds")
        #expect(RunError.stopped.description == "was stopped")
    }

    /// A program stopped alone, as a login shell is, leaves what it started: an ssh-agent its startup files launched is
    /// not SitRep's to end.
    @Test(.tags(.process))
    func aProgramStoppedAloneLeavesWhatItStarted() async throws {
        let (run, child) = try await Self.started(stopping: .alone)

        defer { Self.end(run, child) }
        let left = try #require(child)

        run.cancel()
        let stopped = try #require(await result(of: run, within: .seconds(5)))

        #expect(throws: RunError.stopped) { try stopped.get() }
        #expect(Self.isAlive(left))
    }

    /// Its task cancelled, as a later click's jump stops this one, or at its limit, which ends it the same way
    /// (`Running.end()`), it is killed with every program it started, and says it was stopped.
    @Test(.tags(.process))
    func aRunWhoseTaskIsCancelledIsKilledWithEveryProgramItStarted() async throws {
        let (run, child) = try await Self.started(stopping: .group)

        defer { Self.end(run, child) }
        let left = try #require(child)

        run.cancel()
        let stopped = try #require(await result(of: run, within: .seconds(5)))

        #expect(throws: RunError.stopped) { try stopped.get() }
        #expect(await Self.isGone(left))
    }

    @Test(.tags(.process))
    func aRunWhoseTaskIsCancelledBeforeItStartsNeverStarts() async throws {
        let touched = FileManager.default.temporaryDirectory.appending(path: "sitrep-run-\(UUID().uuidString)")
        let run = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await runProgram(Self.sh("touch '\(touched.path)'"))
        }

        defer { try? FileManager.default.removeItem(at: touched) }
        let stopped = try #require(await result(of: run, within: .seconds(5)))

        #expect(throws: RunError.stopped) { try stopped.get() }
        #expect(!FileManager.default.fileExists(atPath: touched.path))
    }

    /// A run, under a limit it never meets, of a program that starts a child to outlive it; and the child, once the
    /// program says it has started it.
    private static func started(stopping: Stopping) async throws -> (run: Task<Ran, any Error>, child: pid_t?) {
        let ready = try Handshake()
        let program = sh("sleep 3600 & echo $! > '\(ready.path)'; wait", limit: 60, stopping: stopping)
        let run = Task { try await runProgram(program) }

        return (run, await ready.line().flatMap { pid_t($0) })
    }

    /// The run stopped, and the child it left killed, whatever the test came to.
    private static func end(_ run: Task<Ran, any Error>, _ child: pid_t?) {
        run.cancel()
        if let child {
            kill(child, SIGKILL)
        }
    }

    /// Whether the process runs: there, and no zombie, which `kill(pid, 0)` would count as running.
    private static func isAlive(_ pid: pid_t) -> Bool {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)

        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size && info.pbi_status != SZOMB
    }

    /// Whether the process is gone: as soon as it is, or not within the generous time a loaded Mac may take to kill it.
    private static func isGone(_ pid: pid_t) async -> Bool {
        for _ in 0 ..< 200 where isAlive(pid) {
            try? await Task.sleep(for: .milliseconds(50))
        }

        return !isAlive(pid)
    }
}
