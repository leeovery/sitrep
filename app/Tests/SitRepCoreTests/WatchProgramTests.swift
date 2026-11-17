import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// Real programs watched, each as a child of the test's, every wait on one bounded; a program that may outlive its test
/// first says its own pid, which leads its process group, and starts a child only once the test has read it
/// (`Handshake`), and the group is killed however the test ends.
@Suite(.backstop, .tags(.thisMac))
struct WatchProgramTests {
    private static func sh(_ script: String, environment: [String: String] = [:]) -> Program {
        Program(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], environment: environment, limit: .infinity)
    }

    /// The program watched to its end, what it says heard as it comes.
    private static func watching(
        _ program: Program, holding running: RunningChild = RunningChild(),
        hearing: @escaping @Sendable (Heard) -> Void = { _ in }
    ) -> Task<[Heard], Never> {
        Task {
            var heard: [Heard] = []

            for await said in watchProgram(holding: running)(program) {
                heard.append(said)
                hearing(said)
            }

            return heard
        }
    }

    /// What the program says, to its end; one not ended within the time is read no more, and ends the test.
    private static func heard(
        _ program: Program, holding running: RunningChild = RunningChild(), within limit: Duration = .seconds(30),
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> [Heard] {
        try await value(
            of: watching(program, holding: running), within: limit, "for the program to end", sourceLocation: sourceLocation
        )
    }

    /// The watch read no more, and the program's group killed, whatever the test came to.
    private static func end(_ watching: Task<[Heard], Never>, _ leader: pid_t?) {
        watching.cancel()
        endGroup(of: leader)
    }

    @Test func eachLineIsHeardAsItComesThenHowTheProgramEnded() async throws {
        let heard = try await Self.heard(Self.sh("echo one; echo two; echo err >&2; exit 3"))

        #expect(heard == [.line("one"), .line("two"), .exited(.status(3), stderr: "err")])
    }

    /// Its standard input is empty and at its end, so a program reading it, as `watch` listens to it, hears nothing.
    @Test func theProgramGetsOnlyTheEnvironmentGivenAndNothingOnItsStdin() async throws {
        let heard = try await Self.heard(
            Self.sh(#"/bin/cat; printf '%s|%s\n' "$PATH" "${HOME-unset}""#, environment: ["PATH": "/lee/bin"])
        )

        #expect(heard == [.line("/lee/bin|unset"), .exited(.status(0), stderr: "")])
    }

    @Test func ofALongStderrOnlyTheLastLinesAreKept() async throws {
        let heard = try await Self.heard(Self.sh("i=0; while [ $i -lt 30 ]; do echo $i >&2; i=$((i+1)); done"))

        #expect(heard == [.exited(.status(0), stderr: (10..<30).map(String.init).joined(separator: "\n"))])
    }

    @Test func aProgramStoppedByASignalSaysWhich() async throws {
        #expect(try await Self.heard(Self.sh("kill -9 $$")) == [.exited(.signal(9), stderr: "")])
    }

    /// Its end heard as the program ends, its output read only to the drain's half second: the child it left, holding
    /// that output open and still running, would hold the end to the child's own, an hour on, where the drain was not
    /// cut.
    @Test func aChildLeftHoldingTheOutputOpenIsNotWaitedOn() async throws {
        let (group, child) = (try Handshake(), try Handshake())
        let watching = Self.watching(
            Self.sh("echo $$ > '\(group.path)'; exec 3> '\(child.path)'; echo done; sleep 3600 & echo $! >&3")
        )
        var leader: pid_t?

        defer { Self.end(watching, leader) }
        leader = try await group.leader()

        let left = try await child.pid()
        let heard = try await value(of: watching, within: .seconds(5), "for the program to end")

        #expect(heard == [.line("done"), .exited(.status(0), stderr: "")])
        #expect(isAlive(left))
    }

    /// A line is read whole to 16MB, and cut there.
    @Test func aLineIsReadWholeTo16MBAndCutThere() async throws {
        let longest = 16 << 20
        let heard = try await Self.heard(Self.sh("head -c \(longest + 100) /dev/zero | tr '\\0' a; echo; echo next"))
        let lines = heard.compactMap { said in if case let .line(line) = said { line } else { nil } }

        #expect(lines.map(\.utf8.count) == [longest, 4])
        #expect(try #require(lines.first).utf8.first { $0 != UInt8(ascii: "a") } == nil)
        #expect(heard.last == .exited(.status(0), stderr: ""))
    }

    @Test func aLineOfStderrPastTheLongestKeptIsCutThere() async throws {
        let heard = try await Self.heard(Self.sh("head -c \(longestSaid * 4) /dev/zero | tr '\\0' e >&2"))

        #expect(heard == [.exited(.status(0), stderr: String(repeating: "e", count: longestSaid))])
    }

    @Test func aProgramThatCannotStartSaysSo() async throws {
        let heard = try await Self.heard(
            Program(executable: URL(fileURLWithPath: "/no/such/sitrep"), arguments: [], environment: [:], limit: .infinity)
        )

        guard case .unstartable = try #require(heard.first) else {
            Issue.record("heard \(heard)")
            return
        }

        #expect(heard.count == 1)
    }

    /// Read no more once it says it is ready, it is told to end: stopped any other way, it never says it was told, and
    /// the wait on its word runs out. It sets its trap only once the test, its pid read, listens for that word, so a
    /// program the test never heard from dies of the SIGTERM rather than wait in its trap on a word no one reads.
    @Test func readingNoMoreStopsTheProgramWithSIGTERM() async throws {
        let (group, stopped) = (try Handshake(), try Handshake())
        let program = Self.sh(
            "echo $$ > '\(group.path)'; exec 3> '\(stopped.path)'; trap 'echo TERM >&3; exit 0' TERM; echo ready; "
                + "while :; do sleep 0.05; done"
        )
        let first = Task { () -> Heard? in
            for await said in watchProgram(program) {
                return said
            }

            return nil
        }
        var leader: pid_t?

        defer {
            first.cancel()
            endGroup(of: leader)
        }
        leader = try await group.leader()

        let told = Task { try await stopped.line() }

        #expect(try await value(of: first, within: .seconds(10), "for the program's first word") == .line("ready"))
        #expect(try await result(of: told, within: Handshake.wait).get() == "TERM")
    }

    /// The program waits in the shell's own `wait`, never on a child in the foreground: `Process.terminate` signals
    /// the program's process group, and a foreground child dying of it has the shell say "Terminated: 15" on
    /// stderr, or not, as the two race.
    @Test func theRunningProgramIsHeldAndItsHolderStopsItWithSIGTERM() async throws {
        let (group, child) = (try Handshake(), try Handshake())
        let running = RunningChild()
        let program = Self.sh(
            "echo $$ > '\(group.path)'; exec 3> '\(child.path)'; sleep 60 & echo $! >&3; trap 'exit 0' TERM; echo ready; wait"
        )
        let watching = Self.watching(program, holding: running) { said in
            if said == .line("ready") {
                running.terminate()
            }
        }
        var leader: pid_t?

        defer { Self.end(watching, leader) }
        leader = try await group.leader()
        _ = try await child.pid()

        let heard = try await value(of: watching, within: .seconds(30), "for the program to end")

        #expect(heard == [.line("ready"), .exited(.status(0), stderr: "")])
    }

    @Test func aHolderStoppedStopsAProgramHeldAfterAtOnce() async throws {
        let running = RunningChild()

        running.terminate()
        #expect(try await Self.heard(Self.sh("exec sleep 5"), holding: running) == [.exited(.signal(SIGTERM), stderr: "")])
    }
}
