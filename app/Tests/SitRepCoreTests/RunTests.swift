import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// Real programs run, each as a child of the test's: a guard against a run that never ends, the suite's time limit.
@Suite(.timeLimit(.minutes(1)), .tags(.process))
struct RunTests {
    private static func sh(
        _ script: String, environment: [String: String] = [:], limit: TimeInterval = 5, stopping: Stopping = .alone
    ) -> Program {
        Program(
            executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], environment: environment,
            limit: limit, stopping: stopping
        )
    }

    @Test func aRunGivesTheExitStatusAndBothOutputs() async throws {
        let ran = try await runProgram(Self.sh("echo out; echo err >&2; exit 3"))

        #expect(ran == Ran(status: 3, stdout: "out\n", stderr: "err\n"))
    }

    @Test func theProgramGetsOnlyTheEnvironmentGiven() async throws {
        let ran = try await runProgram(Self.sh(#"printf '%s|%s' "$PATH" "${HOME-unset}""#, environment: ["PATH": "/lee/bin"]))

        #expect(ran.stdout == "/lee/bin|unset")
    }

    @Test func stdinIsEmpty() async throws {
        let ran = try await runProgram(Self.sh("cat; echo read"))

        #expect(ran.stdout == "read\n")
    }

    @Test func outputLargerThanAPipeHoldsIsReadWhole() async throws {
        let ran = try await runProgram(Self.sh("head -c 200000 /dev/zero | tr '\\0' x"))

        #expect(ran.stdout.count == 200_000)
    }

    @Test func aProgramThatCannotStartIsUnstartable() async {
        let missing = Program(executable: URL(fileURLWithPath: "/no/such/sitrep"), arguments: [], environment: [:], limit: 5)

        await #expect {
            try await runProgram(missing)
        } throws: { error in
            if case .unstartable = error as? RunError { true } else { false }
        }
    }

    /// Killed at its limit: never killed, it would run on for an hour, and the suite's time limit would fail it.
    @Test func aProgramOutlivingItsLimitIsKilledAndTimedOut() async {
        await #expect(throws: RunError.timedOut(0.3)) { try await runProgram(Self.sh("sleep 3600", limit: 0.3)) }
    }

    /// An interactive shell ignores SIGTERM, so the kill must be one it cannot ignore.
    @Test func aProgramIgnoringTermIsKilledAllTheSame() async {
        let trapped = Self.scratch()
        let script = "trap '' TERM; echo trapped > '\(trapped.path)'; while :; do sleep 1; done"

        defer { try? FileManager.default.removeItem(at: trapped) }
        await #expect(throws: RunError.timedOut(1)) { try await runProgram(Self.sh(script, limit: 1)) }
        #expect(Self.read(trapped) == "trapped", "killed before it set its trap, so its kill proves nothing")
    }

    /// The run ends as the program does, its output read: the child it left, holding that output open, still runs.
    @Test func aChildLeftHoldingTheOutputOpenIsNotWaitedOn() async throws {
        let pidFile = Self.scratch()
        let ran = try await runProgram(Self.sh("echo done; sleep 3600 & echo $! > '\(pidFile.path)'", limit: 20))
        let left = try Self.pid(in: pidFile)

        defer { kill(left, SIGKILL) }
        #expect(ran == Ran(status: 0, stdout: "done\n", stderr: ""))
        #expect(kill(left, 0) == 0)
    }

    @Test func timingOutIsToldInWords() {
        #expect(RunError.timedOut(30).description == "did not answer within 30 seconds")
        #expect(RunError.stopped.description == "was stopped")
    }

    /// Killed at its limit, a group stop takes its whole process group: nothing the program started is left.
    @Test func aProgramOutlivingItsLimitIsKilledWithEveryProgramItStarted() async throws {
        let pidFile = Self.scratch()
        let program = Self.sh("sleep 3600 & echo $! > '\(pidFile.path)'; wait", limit: 1, stopping: .group)

        await #expect(throws: RunError.timedOut(1)) { try await runProgram(program) }

        let left = try Self.pid(in: pidFile)

        #expect(await Self.isGone(left))
    }

    /// A program stopped alone, as a login shell is, leaves what it started: an ssh-agent its startup files launched is
    /// not SitRep's to end.
    @Test func aProgramStoppedAloneLeavesWhatItStarted() async throws {
        let (run, started) = try await Self.started(stopping: .alone)
        let left = try #require(pid_t(started))

        defer { kill(left, SIGKILL) }
        run.cancel()
        await #expect(throws: RunError.stopped) { try await run.value }
        #expect(kill(left, 0) == 0)
    }

    /// Its task cancelled, as a later click's jump stops this one, it is killed with every program it started, and
    /// says it was stopped.
    @Test func aRunWhoseTaskIsCancelledIsKilledWithEveryProgramItStarted() async throws {
        let (run, started) = try await Self.started(stopping: .group)
        let left = try #require(pid_t(started))

        run.cancel()
        await #expect(throws: RunError.stopped) { try await run.value }
        #expect(await Self.isGone(left))
    }

    @Test func aRunWhoseTaskIsCancelledBeforeItStartsNeverStarts() async {
        let touched = Self.scratch()
        let run = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await runProgram(Self.sh("touch '\(touched.path)'"))
        }

        await #expect(throws: RunError.stopped) { try await run.value }
        #expect(!FileManager.default.fileExists(atPath: touched.path))
    }

    /// A run, under no limit it meets, of a program that starts a child to outlive it, and the child's pid, which the
    /// program says once it has started it.
    private static func started(stopping: Stopping) async throws -> (run: Task<Ran, any Error>, started: String) {
        let ready = try Handshake()
        let program = sh("sleep 3600 & echo $! > '\(ready.path)'; wait", limit: 60, stopping: stopping)
        let run = Task { try await runProgram(program) }

        defer { ready.remove() }
        return (run, await ready.line())
    }

    /// A file of the test's own, not there yet.
    private static func scratch() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "sitrep-run-\(UUID().uuidString)")
    }

    private static func read(_ file: URL) -> String? {
        (try? String(contentsOf: file, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func pid(in file: URL) throws -> pid_t {
        defer { try? FileManager.default.removeItem(at: file) }

        return try #require(read(file).flatMap { pid_t($0) })
    }

    /// Whether the process is gone, killed and reaped by launchd, whose it became: as soon as it is, or not within the
    /// generous time a loaded Mac may take.
    private static func isGone(_ pid: pid_t) async -> Bool {
        for _ in 0 ..< 200 where kill(pid, 0) == 0 {
            try? await Task.sleep(for: .milliseconds(50))
        }

        return kill(pid, 0) != 0 && errno == ESRCH
    }
}
