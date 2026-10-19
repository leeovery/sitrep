import Foundation
@testable import SitRepCore
import Testing

struct WatchProgramTests {
    private static func sh(_ script: String, environment: [String: String] = [:]) -> Program {
        Program(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], environment: environment, limit: .infinity)
    }

    private static func heard(_ program: Program) async -> [Heard] {
        var heard: [Heard] = []

        for await said in watchProgram(program) {
            heard.append(said)
        }

        return heard
    }

    @Test func eachLineIsHeardAsItComesThenHowTheProgramEnded() async {
        let heard = await Self.heard(Self.sh("echo one; echo two; echo err >&2; exit 3"))

        #expect(heard == [.line("one"), .line("two"), .exited(status: 3, stderr: "err")])
    }

    @Test func theProgramGetsOnlyTheEnvironmentGivenAndAnEmptyStdin() async {
        let heard = await Self.heard(Self.sh(#"/bin/cat; printf '%s|%s\n' "$PATH" "${HOME-unset}""#, environment: ["PATH": "/lee/bin"]))

        #expect(heard == [.line("/lee/bin|unset"), .exited(status: 0, stderr: "")])
    }

    @Test func ofALongStderrOnlyTheLastLinesAreKept() async {
        let heard = await Self.heard(Self.sh("i=0; while [ $i -lt 30 ]; do echo $i >&2; i=$((i+1)); done"))

        #expect(heard == [.exited(status: 0, stderr: (10..<30).map(String.init).joined(separator: "\n"))])
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
}
