import Foundation
@testable import SitRepCore
import os
import SitRepLines
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

    @Test func aRunIsThePluginsCLIWithLeesPathAndTheAppsEnvironment() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        _ = await cli.wake("sr-gs7kq2")

        #expect(programs.all == [
            Program(
                executable: URL(fileURLWithPath: "/Users/lee/Code/sitrep/bin/sitrep"),
                arguments: ["wake", "--session", "sr-gs7kq2"],
                environment: ["HOME": "/Users/lee", "PATH": Self.path],
                limit: SitRepCLI.sessionLimit,
                stopping: .group
            ),
        ])
    }

    @Test func aRunThatFailsSayingNothingGivesItsStatus() async {
        let (cli, _) = Self.cli(Self.exited(127, stderr: "  \n"))

        #expect(await cli.wake("sr-gs7kq2") == .refused("sitrep wake ended with status 127."))
    }

    @Test func aFailureNotFromTheCLIIsGivenWhole() async {
        let (cli, _) = Self.cli(Self.exited(127, stderr: "env: bun: No such file or directory\n"))

        #expect(await cli.wake("sr-gs7kq2") == .refused("env: bun: No such file or directory"))
    }

    @Test func ofAManyLinedFailureTheCLIsOwnLineIsGiven() async {
        let stderr = """
        (node:4242) Warning: something Bun said first
        sitrep: There is no session sr-zzzzzz on the board, in any project.
            at main (/Users/lee/Code/sitrep/cli/main.ts:190:12)
        """
        let (cli, _) = Self.cli(Self.exited(2, stderr: stderr))

        #expect(await cli.wake("sr-zzzzzz") == .refused("There is no session sr-zzzzzz on the board, in any project."))
    }

    @Test func ofAManyLinedFailureNotTheCLIsTheFirstLineWithAnythingOnItIsGiven() async {
        let stderr = """

          error: Cannot find module "../cli/shell" from "/Users/lee/Code/sitrep/bin/sitrep"
            at resolve (native:1:1)
            at /Users/lee/Code/sitrep/bin/sitrep:2:1
        """
        let (cli, _) = Self.cli(Self.exited(1, stderr: stderr))

        #expect(await cli.wake("sr-gs7kq2") == .refused(#"error: Cannot find module "../cli/shell" from "/Users/lee/Code/sitrep/bin/sitrep""#))
    }

    @Test func thePathIsAskedForAtEachRun() async {
        let paths = OSAllocatedUnfairLock(initialState: ["/usr/bin:/bin", Self.path])
        let programs = Asked()
        let cli = SitRepCLI(plugin: Self.plugin, path: { paths.withLock { $0.removeFirst() } }, environment: [:]) { program in
            programs.add(program)

            return Ran(status: 0, stdout: "", stderr: "")
        }

        _ = await cli.wake("sr-gs7kq2")
        _ = await cli.wake("sr-gs7kq2")

        #expect(programs.all.map { $0.environment["PATH"] } == ["/usr/bin:/bin", Self.path])
    }

    @Test func aCLIThatCannotStartSaysSo() async {
        let (cli, _) = Self.cli { _ in throw RunError.unstartable("no such file") }

        #expect(await cli.wake("sr-gs7kq2") == .refused("sitrep wake could not start: no such file."))
    }

    @Test func aWriteThatNeverEndsSaysSo() async {
        let (cli, _) = Self.cli { program in throw RunError.timedOut(program.limit) }

        #expect(await cli.wake("sr-gs7kq2") == .refused("sitrep wake did not answer within 10 seconds."))
    }

    /// A snooze puts off the session, its time in whole milliseconds since the epoch, naming after `--` the asks its
    /// row showed, so the CLI refuses one landed since.
    @Test func snoozeRunsSnoozeWithItsTimeAndTheAsksShownAfterTheirDashes() async {
        let (cli, programs) = Self.cli(Self.exited(0))
        let until = Date(timeIntervalSince1970: 1_792_745_127)

        #expect(await cli.snooze("sr-4g01a7", showing: ["k1", "k3"], until: until) == .written)
        #expect(programs.all.map(\.arguments) == [
            ["snooze", "--until", "1792745127000", "--session", "sr-4g01a7", "--", "k1", "k3"],
        ])
        #expect(programs.all.map(\.limit) == [10])
    }

    /// A turn's row shows no ask: its snooze names none. Until it moves, it gives no time.
    @Test func aTurnsRowIsSnoozedNamingNoAskAndUntilItMovesWithNoTime() async {
        let (cli, programs) = Self.cli(Self.exited(0))
        let until = Date(timeIntervalSince1970: 1_792_745_127)

        #expect(await cli.snooze("sr-4g01a7", showing: [], until: until) == .written)
        #expect(await cli.snooze("sr-4g01a7", showing: ["k1"], until: nil) == .written)
        #expect(programs.all.map(\.arguments) == [
            ["snooze", "--until", "1792745127000", "--session", "sr-4g01a7", "--"],
            ["snooze", "--session", "sr-4g01a7", "--", "k1"],
        ])
    }

    @Test func wakeRunsWakeOfTheSession() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        #expect(await cli.wake("sr-4g01a7") == .written)
        #expect(programs.all.map(\.arguments) == [["wake", "--session", "sr-4g01a7"]])
    }

    @Test(arguments: [
        "Harness is not snoozed.", "An ask waits on Lee that the snooze did not name: look at it, then snooze again.",
    ])
    func aSnoozeOrAWakeRefusedGivesTheCLIsWords(words: String) async {
        let (cli, _) = Self.cli(Self.exited(1, stderr: "sitrep: \(words)\n"))

        #expect(await cli.wake("sr-4g01a7") == .refused(words))
        #expect(await cli.snooze("sr-4g01a7", showing: ["k1"], until: Date()) == .refused(words))
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
