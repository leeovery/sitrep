import Foundation
import os
@testable import SitRepCore
import Testing

struct LoginPathTests {
    private static let path = "/Users/lee/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"
    private static let home = "/Users/lee"
    private static let fallback = "/opt/homebrew/bin:/usr/local/bin:/Users/lee/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    @Test func thePathIsWhatLiesBetweenTheMarkers() {
        #expect(LoginPath.parse("<sitrep-path>\(Self.path)</sitrep-path>") == Self.path)
    }

    @Test func whatTheShellsStartUpPrintsAroundThemIsLeftOut() {
        let output = """
        [oh-my-zsh] Would you like to update? [Y/n]
        \u{1B}]7;file://localhost/Users/lee\u{07}<sitrep-path>\(Self.path)</sitrep-path>\u{1B}[?2004l
        zsh: exit 0
        """

        #expect(LoginPath.parse(output) == Self.path)
    }

    @Test(arguments: [
        "",
        "<sitrep-path></sitrep-path>",
        "<sitrep-path>  \n</sitrep-path>",
        "<sitrep-path>\(path)",
        "\(path)</sitrep-path>",
        "</sitrep-path>\(path)<sitrep-path>",
        path,
    ])
    func noPathWhenAMarkerIsMissingOrNothingIsBetween(output: String) {
        #expect(LoginPath.parse(output) == nil)
    }

    @Test func theShellIsAskedAsALoginAndInteractiveShellWithItsOutputMarked() async throws {
        let program = LoginPath.program(shell: "/bin/zsh", environment: ["HOME": "/Users/lee"])

        #expect(program.executable.path == "/bin/zsh")
        #expect(program.arguments.prefix(3) == ["-l", "-i", "-c"])
        #expect(program.environment == ["HOME": "/Users/lee"])

        let ran = try await runProgram(
            Program(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", program.arguments[3]], environment: ["PATH": Self.path], limit: 5)
        )

        #expect(LoginPath.parse(ran.stdout) == Self.path)
    }

    @Test func theShellsPathIsFound() async {
        let found = await LoginPath.find(shell: "/bin/zsh", home: Self.home, environment: [:]) { _ in
            Ran(status: 0, stdout: "<sitrep-path>\(Self.path)</sitrep-path>", stderr: "")
        }

        #expect(found == .shell(Self.path))
    }

    @Test func noShellFallsBack() async {
        let found = await LoginPath.find(shell: nil, home: Self.home, environment: [:]) { _ in
            Issue.record("no shell to run")

            return Ran(status: 0, stdout: "", stderr: "")
        }

        #expect(found == .fallback(Self.fallback))
    }

    @Test func aShellGivingNoPathFallsBack() async {
        let found = await LoginPath.find(shell: "/bin/zsh", home: Self.home, environment: [:]) { _ in
            Ran(status: 1, stdout: "zsh: command not found: printf", stderr: "")
        }

        #expect(found == .fallback(Self.fallback))
    }

    @Test func aShellThatDoesNotAnswerFallsBack() async {
        let found = await LoginPath.find(shell: "/bin/zsh", home: Self.home, environment: [:]) { program in
            throw RunError.timedOut(program.limit)
        }

        #expect(found == .fallback(Self.fallback))
    }

    @Test func theFallbackPutsHomebrewThenBunBeforeTheSystem() {
        #expect(LoginPath.fallback(home: Self.home) == Self.fallback)
    }
}

struct ShellPathTests {
    /// A shell answering in turn as given, counting how often it is asked.
    private final class Shell: Sendable {
        private let answers: OSAllocatedUnfairLock<[FoundPath]>
        private let count = OSAllocatedUnfairLock(initialState: 0)

        init(_ answers: FoundPath...) {
            self.answers = OSAllocatedUnfairLock(initialState: answers)
        }

        var asked: Int { count.withLock { $0 } }

        func answer() -> FoundPath {
            count.withLock { $0 += 1 }

            return answers.withLock { $0.removeFirst() }
        }
    }

    @Test func theShellsPathIsAskedForOnceAndKept() async {
        let shell = Shell(.shell("/lee/bin"))
        let path = ShellPath { shell.answer() }

        #expect(await path.path() == "/lee/bin")
        #expect(await path.path() == "/lee/bin")
        #expect(shell.asked == 1)
    }

    @Test func aFallbackServesOneRunAndTheShellIsAskedAgainAtTheNext() async {
        let shell = Shell(.fallback("/usr/bin:/bin"), .shell("/lee/bin"))
        let path = ShellPath { shell.answer() }

        #expect(await path.path() == "/usr/bin:/bin")
        #expect(await path.path() == "/lee/bin")
        #expect(await path.path() == "/lee/bin")
        #expect(shell.asked == 2)
    }
}
