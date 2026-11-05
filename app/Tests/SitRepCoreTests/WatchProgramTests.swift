import Foundation
@testable import SitRepCore
import Testing

@Suite(.timeLimit(.minutes(1)))
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

    @Test func aChildLeftHoldingTheOutputOpenIsNotWaitedOn() async {
        let clock = ContinuousClock()
        let started = clock.now
        let heard = await Self.heard(Self.sh("echo done; sleep 10 &"))

        #expect(heard == [.line("done"), .exited(.status(0), stderr: "")])
        #expect(clock.now - started < .seconds(3))
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

    @Test func readingNoMoreStopsTheProgramWithSIGTERM() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let stopped = folder.appending(path: "stopped")

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let script = "trap 'touch \"\(stopped.path)\"; exit 0' TERM; echo ready; while :; do sleep 0.05; done"

        for await said in watchProgram(Self.sh(script)) {
            #expect(said == .line("ready"))
            break
        }

        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)

        while !FileManager.default.fileExists(atPath: stopped.path), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(FileManager.default.fileExists(atPath: stopped.path))
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
