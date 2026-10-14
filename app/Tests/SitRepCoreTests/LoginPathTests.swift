import Foundation
@testable import SitRepCore
import Testing

struct LoginPathTests {
    private static let path = "/Users/lee/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"

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
        let found = await LoginPath.find(shell: "/bin/zsh", environment: [:]) { _ in
            Ran(status: 0, stdout: "<sitrep-path>\(Self.path)</sitrep-path>", stderr: "")
        }

        #expect(found == Self.path)
    }

    @Test func noShellFallsBack() async {
        let found = await LoginPath.find(shell: nil, environment: [:]) { _ in
            Issue.record("no shell to run")

            return Ran(status: 0, stdout: "", stderr: "")
        }

        #expect(found == LoginPath.fallback)
    }

    @Test func aShellGivingNoPathFallsBack() async {
        let found = await LoginPath.find(shell: "/bin/zsh", environment: [:]) { _ in
            Ran(status: 1, stdout: "zsh: command not found: printf", stderr: "")
        }

        #expect(found == LoginPath.fallback)
    }

    @Test func aShellThatDoesNotAnswerFallsBack() async {
        let found = await LoginPath.find(shell: "/bin/zsh", environment: [:]) { program in
            throw RunError.timedOut(program.limit)
        }

        #expect(found == LoginPath.fallback)
    }

    @Test func theFallbackPutsHomebrewBeforeTheSystem() {
        #expect(LoginPath.fallback == "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
    }
}
