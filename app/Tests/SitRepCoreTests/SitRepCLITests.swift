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

        _ = await cli.finish("sr-gs7kq2")

        #expect(programs.all == [
            Program(
                executable: URL(fileURLWithPath: "/Users/lee/Code/sitrep/bin/sitrep"),
                arguments: ["finish", "--session", "sr-gs7kq2"],
                environment: ["HOME": "/Users/lee", "PATH": Self.path],
                limit: SitRepCLI.sessionLimit,
                stopping: .group
            ),
        ])
    }

    @Test func aRunThatFailsSayingNothingGivesItsStatus() async {
        let (cli, _) = Self.cli(Self.exited(127, stderr: "  \n"))

        #expect(await cli.finish("sr-gs7kq2") == .refused("sitrep finish ended with status 127."))
    }

    @Test func aFailureNotFromTheCLIIsGivenWhole() async {
        let (cli, _) = Self.cli(Self.exited(127, stderr: "env: bun: No such file or directory\n"))

        #expect(await cli.finish("sr-gs7kq2") == .refused("env: bun: No such file or directory"))
    }

    @Test func ofAManyLinedFailureTheCLIsOwnLineIsGiven() async {
        let stderr = """
        (node:4242) Warning: something Bun said first
        sitrep: There is no session sr-zzzzzz on the board, in any project.
            at main (/Users/lee/Code/sitrep/cli/main.ts:190:12)
        """
        let (cli, _) = Self.cli(Self.exited(2, stderr: stderr))

        #expect(await cli.finish("sr-zzzzzz") == .refused("There is no session sr-zzzzzz on the board, in any project."))
    }

    @Test func ofAManyLinedFailureNotTheCLIsTheFirstLineWithAnythingOnItIsGiven() async {
        let stderr = """

          error: Cannot find module "../cli/shell" from "/Users/lee/Code/sitrep/bin/sitrep"
            at resolve (native:1:1)
            at /Users/lee/Code/sitrep/bin/sitrep:2:1
        """
        let (cli, _) = Self.cli(Self.exited(1, stderr: stderr))

        #expect(await cli.finish("sr-gs7kq2") == .refused(#"error: Cannot find module "../cli/shell" from "/Users/lee/Code/sitrep/bin/sitrep""#))
    }

    @Test func thePathIsAskedForAtEachRun() async {
        let paths = OSAllocatedUnfairLock(initialState: ["/usr/bin:/bin", Self.path])
        let programs = Asked()
        let cli = SitRepCLI(plugin: Self.plugin, path: { paths.withLock { $0.removeFirst() } }, environment: [:]) { program in
            programs.add(program)

            return Ran(status: 0, stdout: "", stderr: "")
        }

        _ = await cli.finish("sr-gs7kq2")
        _ = await cli.finish("sr-gs7kq2")

        #expect(programs.all.map { $0.environment["PATH"] } == ["/usr/bin:/bin", Self.path])
    }

    @Test func aCLIThatCannotStartSaysSo() async {
        let (cli, _) = Self.cli { _ in throw RunError.unstartable("no such file") }

        #expect(await cli.finish("sr-gs7kq2") == .refused("sitrep finish could not start: no such file."))
    }

    /// The whole jump gives up after 15 seconds, Bun's start and the board's read among it (4 November 2026).
    @Test func jumpRunsTheCLIOnTheWorkWithinFifteenSeconds() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        #expect(await cli.jump(to: "sr-047c7y") == .jumped)
        #expect(programs.all.map(\.arguments) == [["jump", "--session", "sr-047c7y"]])
        #expect(programs.all.map(\.limit) == [15])
    }

    /// Stopped at its limit or by a later click, a jump is told to end, so it puts back its knock's marker, and is
    /// killed with every program it started 300ms on; every other run of the CLI is killed with its group at once.
    @Test func aJumpIsStoppedGentlyAndEveryOtherRunWithItsGroup() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        _ = await cli.jump(to: "sr-047c7y")
        _ = await cli.wake(["k2"], of: "sr-4g01a7")
        _ = await cli.screen()

        #expect(programs.all.map(\.stopping) == [.gently(grace: 0.3), .group, .group])
    }

    /// The CLI's own words for an app that gave no answer in time, as Ghostty killed at its 8 seconds, exiting 3: told
    /// as the limit is, not as a refusal.
    @Test func aJumpTheCLISaysWentUnansweredIsUnanswered() async {
        let words = "Ghostty did not answer within 8 seconds: most likely the Mac is too busy."
        let (cli, _) = Self.cli(Self.exited(3, stderr: "sitrep: \(words)\n"))

        #expect(await cli.jump(to: "sr-047c7y") == .unanswered)
    }

    /// A jump whose task is cancelled before its CLI runs, as a later click lands while the plugin is still being
    /// looked at, never starts its CLI, and ends stopped.
    @Test func aJumpCancelledBeforeItsCLIRunsNeverStartsIt() async {
        let cli = SitRepCLI(plugin: URL(fileURLWithPath: "/no/such/sitrep"), path: { Self.path }, environment: [:])
        let jump = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await cli.jump(to: "sr-047c7y")
        }

        #expect(await jump.value == .stopped)
    }

    @Test(arguments: [
        (1, "Fumi is not on screen: no Ghostty window shows it."),
        (1, "Ghostty did not answer within 5 seconds: most likely the screen is locked, or macOS is asking whether sitrep may control Ghostty."),
        (2, "There is no session sr-zzzzzz on the board, in any project."),
    ] as [(Int32, String)])
    func aJumpRefusedGivesTheCLIsWords(status: Int32, words: String) async {
        let (cli, _) = Self.cli(Self.exited(status, stderr: "sitrep: \(words)\n"))

        #expect(await cli.jump(to: "sr-047c7y") == .refused(words))
    }

    @Test func aJumpThatOutlivesItsLimitIsUnanswered() async {
        let (cli, _) = Self.cli { program in throw RunError.timedOut(program.limit) }

        #expect(await cli.jump(to: "sr-047c7y") == .unanswered)
    }

    @Test func aJumpWhoseRunIsStoppedIsStopped() async {
        let (cli, _) = Self.cli { _ in throw RunError.stopped }

        #expect(await cli.jump(to: "sr-047c7y") == .stopped)
    }

    @Test func screenRunsScreenForJSONAndReadsIt() async throws {
        let (cli, programs) = Self.cli(Self.exited(0, stdout: Lines.screen))

        #expect(await cli.screen() == .read(try ScreenReading.read(Lines.screen)))
        #expect(programs.all.map(\.arguments) == [["screen", "--json"]])
        #expect(programs.all.map(\.limit) == [SitRepCLI.screenLimit])
    }

    @Test func aScreenThatFailsGivesTheCLIsWordsAndNoReading() async {
        let (cli, _) = Self.cli(Self.exited(1, stderr: "sitrep: There is no command screen. sitrep --help lists them.\n"))
        let answer = await cli.screen()

        #expect(answer == .failed("There is no command screen. sitrep --help lists them."))
        #expect(answer.reading == nil)
    }

    @Test func aScreenThatNeverEndsSaysSo() async {
        let (cli, _) = Self.cli { program in throw RunError.timedOut(program.limit) }

        #expect(await cli.screen() == .failed("sitrep screen did not answer within 10 seconds."))
    }

    @Test func aScreenWhoseOutputDoesNotReadSaysSo() async {
        let (cli, _) = Self.cli(Self.exited(0, stdout: #"{"v": 2}"#))

        #expect(
            await cli.screen() == .failed("sitrep screen gave output version 2, and this SitRep reads version 1.")
        )
    }

    @Test func anAnswerGivesTheAskAndTheButtonsWordsAfterTheFlagsEnd() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        #expect(await cli.answer("k2", of: "sr-macapp", with: .words("--Left, the notch's edge")) == .written)
        #expect(programs.all.map(\.arguments) == [
            ["answer", "--session", "sr-macapp", "--", "k2", "--Left, the notch's edge"],
        ])
        #expect(programs.all.map(\.limit) == [10])
    }

    @Test func anIgnoreGivesTheAskAfterTheFlagsEnd() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        #expect(await cli.answer("k3", of: "sr-macapp", with: .ignore) == .written)
        #expect(programs.all.map(\.arguments) == [["answer", "--session", "sr-macapp", "--ignore", "--", "k3"]])
    }

    /// The words the real CLI refused with on 20 October 2026 (`Lines`).
    @Test(arguments: [
        "k2 wants a choice: answer it with “Left, the notch's edge” or “Right”.",
        "An answer to k1 is on its way already.",
    ])
    func anAnswerRefusedGivesTheCLIsWords(words: String) async {
        let (cli, _) = Self.cli(Self.exited(1, stderr: "sitrep: \(words)\n"))

        #expect(await cli.answer("k1", of: "sr-macapp", with: .words("Upward")) == .refused(words))
    }

    @Test func finishRunsFinishOnTheSession() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        #expect(await cli.finish("sr-gs7kq2") == .written)
        #expect(programs.all.map(\.arguments) == [["finish", "--session", "sr-gs7kq2"]])
        #expect(programs.all.map(\.limit) == [10])
    }

    @Test func aFinishRefusedGivesTheCLIsWords() async {
        let words = "The Mac app is open in a window: tell Claude there to finish it."
        let (cli, _) = Self.cli(Self.exited(1, stderr: "sitrep: \(words)\n"))

        #expect(await cli.finish("sr-macapp") == .refused(words))
    }

    @Test func aWriteThatNeverEndsSaysSo() async {
        let (cli, _) = Self.cli { program in throw RunError.timedOut(program.limit) }

        #expect(await cli.finish("sr-gs7kq2") == .refused("sitrep finish did not answer within 10 seconds."))
    }

    /// The asks come after `--`, its time in whole milliseconds since the epoch.
    @Test func snoozeRunsSnoozeWithItsTimeAndTheAsksAfterTheirDashes() async {
        let (cli, programs) = Self.cli(Self.exited(0))
        let until = Date(timeIntervalSince1970: 1_792_745_127)

        #expect(await cli.snooze(["k1", "k3"], of: "sr-4g01a7", until: until) == .written)
        #expect(programs.all.map(\.arguments) == [
            ["snooze", "--until", "1792745127000", "--session", "sr-4g01a7", "--", "k1", "k3"],
        ])
        #expect(programs.all.map(\.limit) == [10])
    }

    @Test func wakeRunsWakeWithTheAsksAfterTheirDashes() async {
        let (cli, programs) = Self.cli(Self.exited(0))

        #expect(await cli.wake(["k2"], of: "sr-4g01a7") == .written)
        #expect(programs.all.map(\.arguments) == [["wake", "--session", "sr-4g01a7", "--", "k2"]])
    }

    @Test(arguments: [
        "k1 is not snoozed.", "Lee's reply to k1 is on its way: it waits on Lee no more.",
    ])
    func aSnoozeOrAWakeRefusedGivesTheCLIsWords(words: String) async {
        let (cli, _) = Self.cli(Self.exited(1, stderr: "sitrep: \(words)\n"))

        #expect(await cli.wake(["k1"], of: "sr-4g01a7") == .refused(words))
        #expect(await cli.snooze(["k1"], of: "sr-4g01a7", until: Date()) == .refused(words))
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
