import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct LastBoardTests {
    private static let noon = Date(timeIntervalSince1970: 1_792_445_600)

    /// The last board after hearing each of what is given in turn, a minute apart from noon, in one run.
    private static func after(_ heard: Heard...) -> LastBoard {
        var last = LastBoard()

        last.begin()

        for (minute, said) in heard.enumerated() {
            _ = last.hear(said, at: noon.addingTimeInterval(Double(minute) * 60))
        }

        return last
    }

    private static func failed(_ stderr: String) -> Stale? {
        after(.exited(.status(1), stderr: stderr)).stale
    }

    @Test func nothingIsKeptUntilALineIsHeardSoTheViewsSayTheyAreLooking() {
        let last = LastBoard()

        #expect(last.board == nil)
        #expect(last.stale == nil)
        #expect(last.staleSince == nil)
    }

    @Test func aLineHeardIsTheBoard() throws {
        let last = Self.after(.line(Lines.pretty))

        #expect(last.board == (try Board.read(Lines.pretty)))
        #expect(last.stale == nil)
    }

    @Test func eachLineHeardReplacesTheLast() throws {
        let last = Self.after(.line(Lines.pretty), .line(watchedEmpty))

        #expect(last.board == (try Board.read(watchedEmpty)))
    }

    @Test func aLineThatDoesNotReadIsSkippedTheBoardKeptAndStaleSinceItCame() throws {
        let last = Self.after(.line(Lines.pretty), .line("sitrep watch, in words"))

        #expect(last.board == (try Board.read(Lines.pretty)))
        #expect(last.stale == .unread(.shape))
        #expect(last.staleSince == Self.noon.addingTimeInterval(60))
        #expect(last.stale?.description == "sitrep watch gave output this SitRep cannot read.")
    }

    @Test func aLineOfAnotherVersionKeepsTheBoardStaleSayingSo() throws {
        let last = Self.after(.line(Lines.pretty), .line(#"{"v": 1}"#))

        #expect(last.board == (try Board.read(Lines.pretty)))
        #expect(last.stale?.description == "sitrep watch gave output version 1, and this SitRep reads version 3.")
    }

    @Test func aLineThatReadsAfterOneThatDidNotIsTheBoardNoLongerStale() throws {
        let last = Self.after(.line(Lines.pretty), .line("not json"), .line(watchedEmpty))

        #expect(last.board == (try Board.read(watchedEmpty)))
        #expect(last.stale == nil)
        #expect(last.staleSince == nil)
    }

    @Test func watchEndingKeepsTheBoardStaleSinceItEndedSayingWhatEndedIt() throws {
        let stderr = "sitrep: EACCES: permission denied, scandir '/Users/me/.local/state/sitrep'\n"
        let last = Self.after(.line(Lines.pretty), .exited(.status(1), stderr: stderr))

        #expect(last.board == (try Board.read(Lines.pretty)))
        #expect(last.stale == .exited(.status(1), said: "EACCES: permission denied, scandir '/Users/me/.local/state/sitrep'"))
        #expect(last.staleSince == Self.noon.addingTimeInterval(60))
        #expect(last.stale?.description == "EACCES: permission denied, scandir '/Users/me/.local/state/sitrep'.")
    }

    @Test func theBoardIsStaleSinceItFirstWentStale() {
        let last = Self.after(.line(Lines.pretty), .line("{"), .exited(.status(1), stderr: ""))

        #expect(last.stale == .exited(.status(1), said: nil))
        #expect(last.staleSince == Self.noon.addingTimeInterval(60))
    }

    @Test func aCrashIsToldByItsErrorNotBunsTrailer() {
        let stderr = """
        error: Cannot find module '../cli/shell' from '/Users/me/Code/sitrep/bin/sitrep'

        Bun v1.4.2 (macOS arm64)

        """

        #expect(Self.failed(stderr)?.description == "error: Cannot find module '../cli/shell' from '/Users/me/Code/sitrep/bin/sitrep'.")
    }

    @Test func aCrashAfterALineOfTheCLIsOwnIsToldByTheCrash() {
        let stderr = """
        sitrep: a folder would not list for a look
        1 | const f = () => {
        2 |   throw new TypeError("boom")
                        ^
        TypeError: boom
              at f (/Users/me/Code/sitrep/cli/watch.ts:2:13)
              at /Users/me/Code/sitrep/cli/watch.ts:4:1

        Bun v1.4.2 (macOS arm64)

        """

        #expect(Self.failed(stderr)?.description == "TypeError: boom.")
    }

    @Test(arguments: [
        (Exit.status(0), "sitrep watch ended."),
        (.status(1), "sitrep watch ended with status 1."),
        (.signal(9), "sitrep watch was stopped (signal 9)."),
    ])
    func watchEndingSayingNothingSaysHowItEnded(exit: Exit, words: String) {
        #expect(Self.after(.exited(exit, stderr: " \n")).stale?.description == words)
    }

    @Test func wordsEndingInTheirOwnPunctuationAreGivenAsTheyAre() {
        #expect(Self.failed("sitrep: There is no session sr-zzzzzz on the board, in any project.\n")?.description
            == "There is no session sr-zzzzzz on the board, in any project.")
    }

    @Test func watchThatCannotStartSaysSo() {
        #expect(Self.after(.unstartable("no such file")).stale?.description == "sitrep watch could not start: no such file.")
    }

    @Test func hearingSaysWhetherWhatTheViewsShowChanged() {
        var last = LastBoard()
        let changes = [
            Heard.line(Lines.pretty),
            .line(Lines.pretty),
            .exited(.status(1), stderr: ""),
            .exited(.status(1), stderr: ""),
            .line(Lines.pretty),
        ].map { last.hear($0, at: Self.noon) }

        #expect(changes == [true, false, true, false, true])
    }

    @Test func everyRunsFirstLineIsItsFirstTheFirstRunsAmongThem() {
        var last = LastBoard()
        var first: [Bool] = []

        func hear(_ heard: Heard) {
            _ = last.hear(heard, at: Self.noon)
            first.append(last.isRunsFirst)
        }

        last.begin()
        hear(.line(watchedEmpty))
        hear(.line(Lines.pretty))
        last.begin()
        hear(.line(watchedEmpty))
        hear(.exited(.status(1), stderr: ""))

        #expect(first == [true, false, true, false])
    }

    /// A first line that does not read is still the run's first, so the next that reads is no longer taken for it:
    /// its `new` is news.
    @Test func aRunsFirstLineThatDoesNotReadIsItsFirstAndTheNextThatReadsIsNot() {
        var last = LastBoard()
        var first: [Bool] = []

        func hear(_ said: Heard) {
            _ = last.hear(said, at: Self.noon)
            first.append(last.isRunsFirst)
        }

        last.begin()
        hear(.line(watchedEmpty))
        last.begin()
        hear(.line("{"))
        hear(.line(Lines.pretty))
        hear(.line(watchedEmpty))

        #expect(first == [true, true, false, false])
    }
}
