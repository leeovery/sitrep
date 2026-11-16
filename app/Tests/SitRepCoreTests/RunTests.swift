import Darwin
import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// Real programs run, each as a child of the test's. Every wait on one is bounded, and a program that may leave a child
/// first says its own pid, which leads its process group, so the group, the child in it, is killed however the test
/// ends, and a run that never ends fails its test and leaves nothing behind.
@Suite(.backstop, .timeLimit(.minutes(1)))
struct RunTests {
    private static func sh(
        _ script: String, environment: [String: String] = [:], limit: TimeInterval = 5, stopping: Stopping = .alone
    ) -> Program {
        Program(
            executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], environment: environment,
            limit: limit, stopping: stopping
        )
    }

    /// How the run ended; one not ended within the time ends the test.
    private static func ran(
        _ program: Program, within limit: Duration = .seconds(20), sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> Result<Ran, any Error> {
        try await result(of: Task { try await runProgram(program) }, within: limit, sourceLocation: sourceLocation)
    }

    @Test(.tags(.thisMac))
    func aRunGivesTheExitStatusAndBothOutputs() async throws {
        let ran = try await Self.ran(Self.sh("echo out; echo err >&2; exit 3")).get()

        #expect(ran == Ran(status: 3, stdout: "out\n", stderr: "err\n"))
    }

    @Test(.tags(.thisMac))
    func theProgramGetsOnlyTheEnvironmentGiven() async throws {
        let ran = try await Self.ran(
            Self.sh(#"printf '%s|%s' "$PATH" "${HOME-unset}""#, environment: ["PATH": "/lee/bin"])
        ).get()

        #expect(ran.stdout == "/lee/bin|unset")
    }

    @Test(.tags(.thisMac))
    func stdinIsEmpty() async throws {
        let ran = try await Self.ran(Self.sh("cat; echo read")).get()

        #expect(ran.stdout == "read\n")
    }

    @Test(.tags(.thisMac))
    func outputLargerThanAPipeHoldsIsReadWhole() async throws {
        let ran = try await Self.ran(Self.sh("head -c 200000 /dev/zero | tr '\\0' x")).get()

        #expect(ran.stdout.count == 200_000)
    }

    @Test(.tags(.thisMac))
    func aProgramThatCannotStartIsUnstartable() async throws {
        let missing = Program(executable: URL(fileURLWithPath: "/no/such/sitrep"), arguments: [], environment: [:], limit: 5)
        let ran = try await Self.ran(missing)

        #expect {
            try ran.get()
        } throws: { error in
            if case .unstartable = error as? RunError { true } else { false }
        }
    }

    /// Killed at its limit, well before its own end: never killed, it would end of itself ten seconds on, and the run
    /// would still be waiting on it at its five.
    @Test(.tags(.thisMac))
    func aProgramOutlivingItsLimitIsKilledAndTimedOut() async throws {
        let ran = try await Self.ran(Self.sh("sleep 10", limit: 0.3), within: .seconds(5))

        #expect(throws: RunError.timedOut(0.3)) { try ran.get() }
    }

    /// At its limit, as at a stop, a program is killed with a signal it cannot ignore, and with `.group` every program
    /// it started: the shell and its child here ignore SIGTERM, as an interactive shell does.
    @Test(.tags(.thisMac))
    func aProgramIgnoringTermIsKilledAtItsLimitWithEveryProgramItStarted() async throws {
        let (group, child) = (try Handshake(), try Handshake())
        let program = Self.sh(
            "trap '' TERM; echo $$ > '\(group.path)'; sleep 3600 & echo $! > '\(child.path)'; wait", limit: 5,
            stopping: .group
        )
        let run = Task { try await runProgram(program) }
        var leader: pid_t?

        defer { Self.end(run, leader) }
        leader = try await group.pid()

        let shell = try #require(leader)
        let left = try await child.pid()
        let ran = try await result(of: run, within: .seconds(30))

        #expect(throws: RunError.timedOut(5)) { try ran.get() }
        #expect(await Self.isGone(shell))
        #expect(await Self.isGone(left))
    }

    /// Stopped as its task is cancelled, once it says it has set its trap, a program ignoring SIGTERM is killed all the
    /// same.
    @Test(.tags(.thisMac))
    func aProgramIgnoringTermIsKilledAllTheSame() async throws {
        let group = try Handshake()
        let program = Self.sh("trap '' TERM; echo $$ > '\(group.path)'; while :; do sleep 1; done", limit: 60)
        let run = Task { try await runProgram(program) }
        var leader: pid_t?

        defer { Self.end(run, leader) }
        leader = try await group.pid()

        let shell = try #require(leader)

        run.cancel()
        await #expect(throws: RunError.stopped) { try await result(of: run, within: .seconds(5)).get() }
        #expect(await Self.isGone(shell))
    }

    /// The run ends as the program does, its output read only to the drain's half second: the child it left, holding
    /// that output open, would hold the run to the child's end, an hour on, where the drain was not cut.
    @Test(.tags(.thisMac))
    func aChildLeftHoldingTheOutputOpenIsNotWaitedOn() async throws {
        let group = try Handshake()
        let program = Self.sh("echo $$ > '\(group.path)'; echo done; sleep 3600 &", limit: 20)
        let run = Task { try await runProgram(program) }
        var leader: pid_t?

        defer { Self.end(run, leader) }
        leader = try await group.pid()

        #expect(try await result(of: run, within: .seconds(5)).get() == Ran(status: 0, stdout: "done\n", stderr: ""))
    }

    @Test func timingOutIsToldInWords() {
        #expect(RunError.timedOut(30).description == "did not answer within 30 seconds")
        #expect(RunError.stopped.description == "was stopped")
    }

    /// A program stopped alone, as a login shell is, leaves what it started: an ssh-agent its startup files launched is
    /// not SitRep's to end.
    @Test(.tags(.thisMac))
    func aProgramStoppedAloneLeavesWhatItStarted() async throws {
        let started = try Started(stopping: .alone)
        var leader: pid_t?

        defer { Self.end(started.run, leader) }
        leader = try await started.group.pid()

        let left = try await started.child.pid()

        started.run.cancel()
        await #expect(throws: RunError.stopped) { try await result(of: started.run, within: .seconds(5)).get() }
        #expect(Self.isAlive(left))
    }

    /// Its task cancelled, as a later click's jump stops this one, it is killed with every program it started, and says
    /// it was stopped.
    @Test(.tags(.thisMac))
    func aRunWhoseTaskIsCancelledIsKilledWithEveryProgramItStarted() async throws {
        let started = try Started(stopping: .group)
        var leader: pid_t?

        defer { Self.end(started.run, leader) }
        leader = try await started.group.pid()

        let left = try await started.child.pid()

        started.run.cancel()
        await #expect(throws: RunError.stopped) { try await result(of: started.run, within: .seconds(5)).get() }
        #expect(await Self.isGone(left))
    }

    @Test(.tags(.thisMac))
    func aRunWhoseTaskIsCancelledBeforeItStartsNeverStarts() async throws {
        let touched = FileManager.default.temporaryDirectory.appending(path: "sitrep-run-\(UUID().uuidString)")
        let program = Self.sh("touch '\(touched.path)'")
        let run = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await runProgram(program)
        }

        defer { try? FileManager.default.removeItem(at: touched) }
        await #expect(throws: RunError.stopped) { try await result(of: run, within: .seconds(5)).get() }
        #expect(!FileManager.default.fileExists(atPath: touched.path))
    }

    /// A run, under a limit it never meets, of a program that says its pid, then starts a child to outlive it and says
    /// the child's.
    private struct Started {
        let group: Handshake
        let child: Handshake
        let run: Task<Ran, any Error>

        init(stopping: Stopping) throws {
            (group, child) = (try Handshake(), try Handshake())

            let program = RunTests.sh(
                "echo $$ > '\(group.path)'; sleep 3600 & echo $! > '\(child.path)'; wait", limit: 60, stopping: stopping
            )

            run = Task { try await runProgram(program) }
        }
    }

    /// The run stopped, and its program's group killed, whatever the test came to.
    private static func end(_ run: Task<Ran, any Error>, _ leader: pid_t?) {
        run.cancel()
        endGroup(of: leader)
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
