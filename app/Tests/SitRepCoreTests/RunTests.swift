import Foundation
@testable import SitRepCore
import Testing

struct RunTests {
    private static func sh(
        _ script: String, environment: [String: String] = [:], limit: TimeInterval = 5, stopping: Stopping = .alone
    ) -> Program {
        Program(
            executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], environment: environment,
            limit: limit, stopping: stopping
        )
    }

    /// How long a run took, and what it came to.
    private static func timed(_ program: Program) async -> (Result<Ran, any Error>, Duration) {
        let clock = ContinuousClock()
        let started = clock.now
        let ended: Result<Ran, any Error>

        do {
            ended = .success(try await runProgram(program))
        } catch {
            ended = .failure(error)
        }

        return (ended, clock.now - started)
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

    @Test func aProgramOutlivingItsLimitIsKilledAndTimedOut() async {
        let (ended, took) = await Self.timed(Self.sh("sleep 10", limit: 0.3))

        #expect(throws: RunError.timedOut(0.3)) { try ended.get() }
        #expect(took < .seconds(3))
    }

    /// An interactive shell ignores SIGTERM, so the kill must be one it cannot ignore.
    @Test func aProgramIgnoringTermIsKilledAllTheSame() async {
        let (ended, took) = await Self.timed(Self.sh("trap '' TERM; while :; do sleep 1; done", limit: 0.3))

        #expect(throws: RunError.timedOut(0.3)) { try ended.get() }
        #expect(took < .seconds(3))
    }

    @Test func aChildLeftHoldingTheOutputOpenIsNotWaitedOn() async throws {
        let (ended, took) = await Self.timed(Self.sh("echo done; sleep 10 &", limit: 20))

        #expect(try ended.get() == Ran(status: 0, stdout: "done\n", stderr: ""))
        #expect(took < .seconds(3))
    }

    @Test func timingOutIsToldInWords() {
        #expect(RunError.timedOut(30).description == "did not answer within 30 seconds")
        #expect(RunError.stopped.description == "was stopped")
    }

    /// Killed at its limit, a group stop takes its whole process group: nothing the CLI started, an osascript among
    /// it, is left to send Ghostty a question late.
    @Test func aProgramOutlivingItsLimitIsKilledWithEveryProgramItStarted() async throws {
        let pidFile = Self.scratch()
        let (ended, _) = await Self.timed(
            Self.sh("sleep 30 & echo $! > '\(pidFile.path)'; wait", limit: 0.5, stopping: .group)
        )

        #expect(throws: RunError.timedOut(0.5)) { try ended.get() }
        #expect(try await Self.isGone(Self.pid(in: pidFile)))
    }

    /// A program stopped alone, as a login shell is, leaves what it started: an ssh-agent its startup files launched is
    /// not SitRep's to end.
    @Test func aProgramStoppedAloneLeavesWhatItStarted() async throws {
        let pidFile = Self.scratch()
        let (ended, _) = await Self.timed(Self.sh("sleep 30 & echo $! > '\(pidFile.path)'; wait", limit: 0.5))
        let left = try Self.pid(in: pidFile)

        defer { kill(left, SIGKILL) }
        #expect(throws: RunError.timedOut(0.5)) { try ended.get() }
        #expect(kill(left, 0) == 0)
    }

    /// Stopped gently, its group is told to end first, so it may put back what it changed before it ends, well inside
    /// its grace.
    @Test func aProgramStoppedGentlyIsToldToEndFirst() async throws {
        let putBack = Self.scratch()
        let script = "trap 'echo put back > \"\(putBack.path)\"; exit 0' TERM; sleep 30 & wait"
        let (ended, took) = await Self.timed(Self.sh(script, limit: 0.5, stopping: .gently(grace: 5)))

        #expect(throws: RunError.timedOut(0.5)) { try ended.get() }
        #expect(String(decoding: try Data(contentsOf: putBack), as: UTF8.self) == "put back\n")
        #expect(took < .seconds(4))
    }

    /// Told to end and ending not, it is killed with its group once the grace has passed.
    @Test func aProgramStoppedGentlyThatWillNotEndIsKilledAfterItsGrace() async throws {
        let pidFile = Self.scratch()
        let script = "trap '' TERM; sleep 30 & echo $! > '\(pidFile.path)'; wait"
        let (ended, took) = await Self.timed(Self.sh(script, limit: 0.3, stopping: .gently(grace: 0.3)))

        #expect(throws: RunError.timedOut(0.3)) { try ended.get() }
        #expect(took >= .milliseconds(600))
        #expect(try await Self.isGone(Self.pid(in: pidFile)))
    }

    /// Its task cancelled, as a later click's jump stops this one, it is killed with every program it started, and
    /// says it was stopped.
    @Test func aRunWhoseTaskIsCancelledIsKilledWithEveryProgramItStarted() async throws {
        let pidFile = Self.scratch()
        let clock = ContinuousClock()
        let run = Task {
            try await runProgram(Self.sh("sleep 30 & echo $! > '\(pidFile.path)'; wait", limit: 20, stopping: .group))
        }

        for _ in 0 ..< 100 where (try? Self.pid(in: pidFile)) == nil {
            try await Task.sleep(for: .milliseconds(50))
        }

        let stopped = clock.now

        run.cancel()
        await #expect(throws: RunError.stopped) { try await run.value }
        #expect(clock.now - stopped < .seconds(3))
        #expect(try await Self.isGone(Self.pid(in: pidFile)))
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

    /// Told to end, the leader goes at once while what it started ignores it: that is killed once the grace has
    /// passed, with the group, though its leader has ended.
    @Test func whatALeaderLeftIgnoringTheSignalIsKilledAfterTheGrace() async throws {
        let pidFile = Self.scratch()
        let script = "trap 'exit 0' TERM; (trap '' TERM; sleep 30) & echo $! > '\(pidFile.path)'; wait"
        let (ended, _) = await Self.timed(Self.sh(script, limit: 0.3, stopping: .gently(grace: 0.3)))

        #expect(throws: RunError.timedOut(0.3)) { try ended.get() }
        #expect(try await Self.isGone(Self.pid(in: pidFile)))
    }

    /// A stop and the limit together tell the program to end once.
    @Test func aProgramIsToldToEndOnceHoweverManyAsk() async throws {
        let told = Self.scratch()
        let process = Process()
        let running = Running(.gently(grace: 30))

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "trap 'echo told >> \"\(told.path)\"' TERM; while :; do sleep 0.05; done"]
        try process.run()
        defer { kill(-process.processIdentifier, SIGKILL) }
        try await Task.sleep(for: .milliseconds(300))

        running.started(process.processIdentifier)
        running.stop()
        running.end()
        try await Task.sleep(for: .milliseconds(500))

        #expect(String(decoding: try Data(contentsOf: told), as: UTF8.self) == "told\n")
    }

    /// A file of the test's own, not there yet.
    private static func scratch() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "sitrep-run-\(UUID().uuidString)")
    }

    private static func pid(in file: URL) throws -> pid_t {
        let text = String(decoding: try Data(contentsOf: file), as: UTF8.self)

        return try #require(pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    /// Whether the process is gone, within a few seconds: killed, it is reaped by launchd, whose it became.
    private static func isGone(_ pid: pid_t) async throws -> Bool {
        for _ in 0 ..< 60 where kill(pid, 0) == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }

        return kill(pid, 0) != 0 && errno == ESRCH
    }
}
