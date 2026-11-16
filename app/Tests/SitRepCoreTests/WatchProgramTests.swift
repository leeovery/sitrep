import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

@Suite(.timeLimit(.minutes(1)), .tags(.process))
struct WatchProgramTests {
    private static func sh(_ script: String, environment: [String: String] = [:]) -> Program {
        Program(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], environment: environment, limit: .infinity)
    }

    /// What the program says.
    private static func heard(_ program: Program) async -> [Heard] {
        var heard: [Heard] = []

        for await said in watchProgram(program) {
            heard.append(said)
        }

        return heard
    }

    @Test func eachLineIsHeardAsItComesThenHowTheProgramEnded() async {
        let heard = await Self.heard(Self.sh("echo one; echo two; echo err >&2; exit 3"))

        #expect(heard == [.line("one"), .line("two"), .exited(.status(3), stderr: "err")])
    }

    /// Its standard input is empty and at its end, so a program reading it, as `watch` listens to it, hears nothing.
    @Test func theProgramGetsOnlyTheEnvironmentGivenAndNothingOnItsStdin() async {
        let heard = await Self.heard(
            Self.sh(#"/bin/cat; printf '%s|%s\n' "$PATH" "${HOME-unset}""#, environment: ["PATH": "/lee/bin"])
        )

        #expect(heard == [.line("/lee/bin|unset"), .exited(.status(0), stderr: "")])
    }

    @Test func ofALongStderrOnlyTheLastLinesAreKept() async {
        let heard = await Self.heard(Self.sh("i=0; while [ $i -lt 30 ]; do echo $i >&2; i=$((i+1)); done"))

        #expect(heard == [.exited(.status(0), stderr: (10..<30).map(String.init).joined(separator: "\n"))])
    }

    @Test func aProgramStoppedByASignalSaysWhich() async {
        #expect(await Self.heard(Self.sh("kill -9 $$")) == [.exited(.signal(9), stderr: "")])
    }

    /// Its end heard as the program ends: the child it left, holding its output open, still runs.
    @Test func aChildLeftHoldingTheOutputOpenIsNotWaitedOn() async throws {
        let ready = try Handshake()
        let watching = Task { await Self.heard(Self.sh("echo done; sleep 3600 & echo $! > '\(ready.path)'")) }
        let left = try #require(pid_t(await ready.line()))

        defer {
            kill(left, SIGKILL)
            ready.remove()
        }
        #expect(await watching.value == [.line("done"), .exited(.status(0), stderr: "")])
        #expect(kill(left, 0) == 0)
    }

    /// A line is read whole to 16MB, and cut there.
    @Test func aLineIsReadWholeTo16MBAndCutThere() async {
        let longest = 16 << 20
        let heard = await Self.heard(Self.sh("head -c \(longest + 100) /dev/zero | tr '\\0' a; echo; echo next"))
        let lines = heard.compactMap { said in if case let .line(line) = said { line } else { nil } }

        #expect(lines.map(\.utf8.count) == [longest, 4])
        #expect(lines.first?.utf8.allSatisfy { $0 == UInt8(ascii: "a") } == true)
        #expect(heard.last == .exited(.status(0), stderr: ""))
    }

    @Test func aLineOfStderrPastTheLongestKeptIsCutThere() async {
        let heard = await Self.heard(Self.sh("head -c \(longestSaid * 4) /dev/zero | tr '\\0' e >&2"))

        #expect(heard == [.exited(.status(0), stderr: String(repeating: "e", count: longestSaid))])
    }

    @Test func aProgramThatCannotStartSaysSo() async throws {
        let heard = await Self.heard(Program(executable: URL(fileURLWithPath: "/no/such/sitrep"), arguments: [], environment: [:], limit: .infinity))

        guard case .unstartable = try #require(heard.first) else {
            Issue.record("heard \(heard)")
            return
        }

        #expect(heard.count == 1)
    }

    /// Stopped by anything else, the program never says it was: the suite's time limit fails the wait on its word.
    @Test func readingNoMoreStopsTheProgramWithSIGTERM() async throws {
        let stopped = try Handshake()
        let script = "trap 'echo TERM > \"\(stopped.path)\"; exit 0' TERM; echo ready; while :; do sleep 0.05; done"

        defer { stopped.remove() }
        for await said in watchProgram(Self.sh(script)) {
            #expect(said == .line("ready"))
            break
        }

        #expect(await stopped.line() == "TERM")
    }

    /// The program waits in the shell's own `wait`, never on a child in the foreground: `Process.terminate` signals
    /// the program's process group, and a foreground child dying of it has the shell say "Terminated: 15" on
    /// stderr, or not, as the two race.
    @Test func theRunningProgramIsHeldAndItsHolderStopsItWithSIGTERM() async {
        let running = RunningChild()
        var heard: [Heard] = []

        for await said in watchProgram(holding: running)(Self.sh("sleep 60 & trap 'exit 0' TERM; echo ready; wait")) {
            heard.append(said)

            if said == .line("ready") {
                running.terminate()
            }
        }

        #expect(heard == [.line("ready"), .exited(.status(0), stderr: "")])
    }

    @Test func aHolderStoppedStopsAProgramHeldAfterAtOnce() async {
        let running = RunningChild()
        var heard: [Heard] = []

        running.terminate()
        for await said in watchProgram(holding: running)(Self.sh("exec sleep 5")) {
            heard.append(said)
        }

        #expect(heard == [.exited(.signal(SIGTERM), stderr: "")])
    }
}
