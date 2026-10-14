import Foundation
@testable import SitRepCore
import os
import Testing

struct SitRepCLITests {
    private static let plugin = URL(fileURLWithPath: "/Users/lee/Code/sitrep")
    private static let path = "/Users/lee/.bun/bin:/opt/homebrew/bin:/usr/bin:/bin"

    /// The CLI with every run answered as given, the programs it ran kept.
    private static func cli(_ answer: @escaping @Sendable (Program) throws -> Ran) -> (SitRepCLI, Asked) {
        let programs = Asked()
        let cli = SitRepCLI(plugin: plugin, path: { path }, environment: ["HOME": "/Users/lee", "PATH": "/usr/bin:/bin"]) { program in
            programs.add(program)

            return try answer(program)
        }

        return (cli, programs)
    }

    private static func exited(_ status: Int32, stdout: String = "", stderr: String = "") -> @Sendable (Program) -> Ran {
        { _ in Ran(status: status, stdout: stdout, stderr: stderr) }
    }

    @Test func listRunsThePluginsCLIWithLeesPathAndTheAppsEnvironment() async {
        let (cli, programs) = Self.cli(Self.exited(0, stdout: listedEmpty))

        _ = await cli.list()

        #expect(programs.all == [
            Program(
                executable: URL(fileURLWithPath: "/Users/lee/Code/sitrep/bin/sitrep"),
                arguments: ["list", "--json"],
                environment: ["HOME": "/Users/lee", "PATH": Self.path],
                limit: SitRepCLI.listLimit
            ),
        ])
    }

    @Test func listGivesTheWorksOnScreen() async {
        let (cli, _) = Self.cli(Self.exited(0, stdout: listed))

        #expect(await cli.list() == .works([
            OnScreen(id: "sr-047c7y", project: "Fumi", name: "Management window discussion"),
            OnScreen(id: "sr-sa13jv", project: "Fumi", name: "Commercialization discussion"),
            OnScreen(id: "sr-y4d0qj", project: "Switchboard", name: "Milestone 7 stages 4 to 14"),
        ]))
    }

    @Test func aListThatFailsGivesTheCLIsOwnWords() async {
        let (cli, _) = Self.cli(Self.exited(1, stderr: "sitrep: EACCES: permission denied, scandir '/Users/lee/.local/state/sitrep'\n"))

        #expect(await cli.list() == .failed("EACCES: permission denied, scandir '/Users/lee/.local/state/sitrep'"))
    }

    @Test func aListThatFailsSayingNothingGivesItsStatus() async {
        let (cli, _) = Self.cli(Self.exited(127, stderr: "  \n"))

        #expect(await cli.list() == .failed("sitrep list ended with status 127."))
    }

    @Test func aFailureNotFromTheCLIIsGivenWhole() async {
        let (cli, _) = Self.cli(Self.exited(127, stderr: "env: bun: No such file or directory\n"))

        #expect(await cli.list() == .failed("env: bun: No such file or directory"))
    }

    @Test func ofAManyLinedFailureTheCLIsOwnLineIsGiven() async {
        let stderr = """
        (node:4242) Warning: something Bun said first
        sitrep: There is no piece of work sr-zzzzzz on the board, in any project.
            at main (/Users/lee/Code/sitrep/cli/main.ts:190:12)
        """
        let (cli, _) = Self.cli(Self.exited(2, stderr: stderr))

        #expect(await cli.list() == .failed("There is no piece of work sr-zzzzzz on the board, in any project."))
    }

    @Test func ofAManyLinedFailureNotTheCLIsTheFirstLineWithAnythingOnItIsGiven() async {
        let stderr = """

          error: Cannot find module "../cli/shell" from "/Users/lee/Code/sitrep/bin/sitrep"
            at resolve (native:1:1)
            at /Users/lee/Code/sitrep/bin/sitrep:2:1
        """
        let (cli, _) = Self.cli(Self.exited(1, stderr: stderr))

        #expect(await cli.list() == .failed(#"error: Cannot find module "../cli/shell" from "/Users/lee/Code/sitrep/bin/sitrep""#))
    }

    @Test func thePathIsAskedForAtEachRun() async {
        let paths = OSAllocatedUnfairLock(initialState: ["/usr/bin:/bin", Self.path])
        let programs = Asked()
        let cli = SitRepCLI(plugin: Self.plugin, path: { paths.withLock { $0.removeFirst() } }, environment: [:]) { program in
            programs.add(program)

            return Ran(status: 0, stdout: listedEmpty, stderr: "")
        }

        _ = await cli.list()
        _ = await cli.list()

        #expect(programs.all.map { $0.environment["PATH"] } == ["/usr/bin:/bin", Self.path])
    }

    @Test func aListOfAnotherVersionSaysSo() async {
        let (cli, _) = Self.cli(Self.exited(0, stdout: #"{"v": 2, "projects": []}"#))

        #expect(await cli.list() == .failed("sitrep list gave output version 2, and this SitRep reads version 1."))
    }

    @Test func aListThatIsNotJSONSaysSo() async {
        let (cli, _) = Self.cli(Self.exited(0, stdout: "SitRep\n  sr-aw3bgs  Menu bar"))

        #expect(await cli.list() == .failed("sitrep list gave output this SitRep cannot read."))
    }

    @Test func aListThatNeverEndsSaysSo() async {
        let (cli, _) = Self.cli { program in throw RunError.timedOut(program.limit) }

        #expect(await cli.list() == .failed("sitrep list did not answer within 10 seconds."))
    }

    @Test func aCLIThatCannotStartSaysSo() async {
        let (cli, _) = Self.cli { _ in throw RunError.unstartable("no such file") }

        #expect(await cli.list() == .failed("sitrep list could not start: no such file."))
    }

    @Test func jumpRunsTheCLIOnTheWorkWithTimeForItsLongestJump() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        #expect(await cli.jump(to: "sr-047c7y") == .jumped)
        #expect(programs.all.map(\.arguments) == [["jump", "--work", "sr-047c7y"]])
        #expect(programs.all.map(\.limit) == [120])
    }

    @Test(arguments: [
        (1, "Fumi is not on screen: no Ghostty window shows it."),
        (1, "Ghostty did not answer within 5 seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty."),
        (2, "There is no piece of work sr-zzzzzz on the board, in any project."),
    ] as [(Int32, String)])
    func aJumpRefusedGivesTheCLIsWords(status: Int32, words: String) async {
        let (cli, _) = Self.cli(Self.exited(status, stderr: "sitrep: \(words)\n"))

        #expect(await cli.jump(to: "sr-047c7y") == .refused(words))
    }

    @Test func aJumpThatNeverEndsSaysSo() async {
        let (cli, _) = Self.cli { program in throw RunError.timedOut(program.limit) }

        #expect(await cli.jump(to: "sr-047c7y") == .refused("sitrep jump did not answer within 120 seconds."))
    }
}

/// The programs a fake runner was asked to run, in order.
private final class Asked: Sendable {
    private let kept = OSAllocatedUnfairLock<[Program]>(initialState: [])

    func add(_ program: Program) {
        kept.withLock { $0.append(program) }
    }

    var all: [Program] { kept.withLock { $0 } }
}
