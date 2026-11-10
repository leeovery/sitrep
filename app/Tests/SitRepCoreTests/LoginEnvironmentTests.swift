import Foundation
import os
@testable import SitRepCore
import Testing

struct LoginEnvironmentTests {
    private static let path = "/Users/lee/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"
    private static let home = "/Users/lee"
    private static let fallback = "/opt/homebrew/bin:/usr/local/bin:/Users/lee/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    /// The variables as `env -0` prints them, between the markers.
    private static func marked(_ variables: [String]) -> String {
        "<sitrep-environment>" + variables.map { $0 + "\0" }.joined() + "</sitrep-environment>"
    }

    @Test func theEnvironmentIsWhatLiesBetweenTheMarkersEachVariableEndedByANul() {
        let output = Self.marked(["PATH=\(Self.path)", "ZMX_DIR=/Users/lee/.local/state/zmx", "EMPTY="])

        #expect(LoginEnvironment.parse(output) == [
            "PATH": Self.path, "ZMX_DIR": "/Users/lee/.local/state/zmx", "EMPTY": "",
        ])
    }

    /// A value is everything after its first `=`, a newline or an `=` of its own kept.
    @Test func aValueKeepsItsNewlinesAndItsEquals() {
        let output = Self.marked(["PATH=\(Self.path)", "PROMPT=a=b\nc"])

        #expect(LoginEnvironment.parse(output)?["PROMPT"] == "a=b\nc")
    }

    @Test func whatTheShellsStartUpPrintsAroundThemIsLeftOut() {
        let output = """
        [oh-my-zsh] Would you like to update? [Y/n]
        \u{1B}]7;file://localhost/Users/lee\u{07}\(Self.marked(["PATH=\(Self.path)"]))\u{1B}[?2004l
        zsh: exit 0
        """

        #expect(LoginEnvironment.parse(output) == ["PATH": Self.path])
    }

    @Test(arguments: [
        "",
        "<sitrep-environment></sitrep-environment>",
        "<sitrep-environment>PATH=  \n\0</sitrep-environment>",
        "<sitrep-environment>HOME=/Users/lee\0</sitrep-environment>",
        "<sitrep-environment>PATH=\(path)\0",
        "PATH=\(path)\0</sitrep-environment>",
        "</sitrep-environment>PATH=\(path)\0<sitrep-environment>",
        "PATH=\(path)",
    ])
    func noEnvironmentWhenAMarkerIsMissingOrItGivesNoPath(output: String) {
        #expect(LoginEnvironment.parse(output) == nil)
    }

    /// The shell's command, run by a shell here, prints what `parse` reads: the variables given it, the system's
    /// `env` found whatever the PATH.
    @Test func theShellIsAskedAsALoginAndInteractiveShellWithItsOutputMarked() async throws {
        let program = LoginEnvironment.program(shell: "/bin/zsh", environment: ["HOME": "/Users/lee"])

        #expect(program.executable.path == "/bin/zsh")
        #expect(program.arguments.prefix(3) == ["-l", "-i", "-c"])
        #expect(program.environment == ["HOME": "/Users/lee"])

        let ran = try await runProgram(
            Program(
                executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", program.arguments[3]],
                environment: ["PATH": Self.path, "ZMX_DIR": "/Users/lee/.local/state/zmx"], limit: 5
            )
        )
        let found = LoginEnvironment.parse(ran.stdout)

        #expect(found?["PATH"] == Self.path)
        #expect(found?["ZMX_DIR"] == "/Users/lee/.local/state/zmx")
    }

    @Test func theShellsEnvironmentIsFound() async {
        let found = await LoginEnvironment.find(shell: "/bin/zsh", home: Self.home, environment: [:]) { _ in
            Ran(status: 0, stdout: Self.marked(["PATH=\(Self.path)", "ZMX_DIR=/z"]), stderr: "")
        }

        #expect(found == .shell(["PATH": Self.path, "ZMX_DIR": "/z"]))
        #expect(found.path == Self.path)
    }

    @Test func noShellFallsBackToSitRepsOwnWithTheFallbackPath() async {
        let found = await LoginEnvironment.find(
            shell: nil, home: Self.home, environment: ["HOME": Self.home, "PATH": "/usr/bin:/bin"]
        ) { _ in
            Issue.record("no shell to run")

            return Ran(status: 0, stdout: "", stderr: "")
        }

        #expect(found == .fallback(["HOME": Self.home, "PATH": Self.fallback]))
    }

    @Test func aShellGivingNoPathFallsBack() async {
        let found = await LoginEnvironment.find(shell: "/bin/zsh", home: Self.home, environment: [:]) { _ in
            Ran(status: 1, stdout: "zsh: command not found: printf", stderr: "")
        }

        #expect(found == .fallback(["PATH": Self.fallback]))
    }

    @Test func aShellThatDoesNotAnswerFallsBack() async {
        let found = await LoginEnvironment.find(shell: "/bin/zsh", home: Self.home, environment: [:]) { program in
            throw RunError.timedOut(program.limit)
        }

        #expect(found == .fallback(["PATH": Self.fallback]))
    }

    @Test func theFallbackPutsHomebrewThenBunBeforeTheSystem() {
        #expect(LoginEnvironment.fallback(home: Self.home) == Self.fallback)
    }
}

struct ShellEnvironmentTests {
    /// A shell answering in turn as given, counting how often it is asked.
    private final class Shell: Sendable {
        private let answers: OSAllocatedUnfairLock<[FoundEnvironment]>
        private let count = OSAllocatedUnfairLock(initialState: 0)

        init(_ answers: FoundEnvironment...) {
            self.answers = OSAllocatedUnfairLock(initialState: answers)
        }

        var asked: Int { count.withLock { $0 } }

        func answer() -> FoundEnvironment {
            count.withLock { $0 += 1 }

            return answers.withLock { $0.removeFirst() }
        }
    }

    @Test func theShellsEnvironmentIsAskedForOnceAndKeptItsPathAmongIt() async {
        let shell = Shell(.shell(["PATH": "/lee/bin", "ZMX_DIR": "/z"]))
        let environment = ShellEnvironment { shell.answer() }

        #expect(await environment.environment() == ["PATH": "/lee/bin", "ZMX_DIR": "/z"])
        #expect(await environment.path() == "/lee/bin")
        #expect(shell.asked == 1)
    }

    @Test func aFallbackServesOneRunAndTheShellIsAskedAgainAtTheNext() async {
        let shell = Shell(.fallback(["PATH": "/usr/bin:/bin"]), .shell(["PATH": "/lee/bin"]))
        let environment = ShellEnvironment { shell.answer() }

        #expect(await environment.path() == "/usr/bin:/bin")
        #expect(await environment.path() == "/lee/bin")
        #expect(await environment.environment() == ["PATH": "/lee/bin"])
        #expect(shell.asked == 2)
    }
}
