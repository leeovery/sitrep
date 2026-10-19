@testable import SitRepCore
import Testing

struct LastBoardTests {
    /// The last board after hearing each of what is given in turn.
    private static func after(_ heard: Heard...) -> LastBoard {
        var last = LastBoard()

        heard.forEach { _ = last.hear($0) }

        return last
    }

    @Test func nothingIsKeptUntilALineIsHeardSoTheViewsSayTheyAreLooking() {
        let last = LastBoard()

        #expect(last.board == nil)
        #expect(last.stale == nil)
    }

    @Test func aLineHeardIsTheBoard() throws {
        let last = Self.after(.line(watched))

        #expect(last.board == (try Board.read(watched)))
        #expect(last.stale == nil)
    }

    @Test func eachLineHeardReplacesTheLast() throws {
        let last = Self.after(.line(watched), .line(watchedEmpty))

        #expect(last.board == (try Board.read(watchedEmpty)))
    }

    @Test func aLineThatDoesNotReadIsSkippedTheBoardKeptAndStaleSayingWhy() throws {
        let last = Self.after(.line(watched), .line("sitrep watch, in words"))

        #expect(last.board == (try Board.read(watched)))
        #expect(last.stale == .unread(.shape))
        #expect(last.stale?.description == "sitrep watch gave output this SitRep cannot read.")
    }

    @Test func aLineOfAnotherVersionKeepsTheBoardStaleSayingSo() throws {
        let last = Self.after(.line(watched), .line(#"{"v": 2}"#))

        #expect(last.board == (try Board.read(watched)))
        #expect(last.stale?.description == "sitrep watch gave output version 2, and this SitRep reads version 1.")
    }

    @Test func aLineThatReadsAfterOneThatDidNotIsTheBoardNoLongerStale() throws {
        let last = Self.after(.line(watched), .line("not json"), .line(watchedEmpty))

        #expect(last.board == (try Board.read(watchedEmpty)))
        #expect(last.stale == nil)
    }

    @Test func watchEndingKeepsTheBoardStaleWithTheLastLineOfItsOwnItSaid() throws {
        let stderr = """
        sitrep: a first complaint
        sitrep: EACCES: permission denied, scandir '/Users/lee/.local/state/sitrep'
            at look (/Users/lee/Code/sitrep/cli/watch.ts:80:3)
        """
        let last = Self.after(.line(watched), .exited(status: 1, stderr: stderr))

        #expect(last.board == (try Board.read(watched)))
        #expect(last.stale == .exited(status: 1, said: "EACCES: permission denied, scandir '/Users/lee/.local/state/sitrep'"))
        #expect(last.stale?.description == "EACCES: permission denied, scandir '/Users/lee/.local/state/sitrep'")
    }

    @Test func watchEndingSayingNothingOfItsOwnGivesItsLastLine() {
        let stderr = """
        error: Cannot find module "../cli/shell" from "/Users/lee/Code/sitrep/bin/sitrep"
            at /Users/lee/Code/sitrep/bin/sitrep:2:1

        """

        #expect(Self.after(.exited(status: 1, stderr: stderr)).stale?.description == "at /Users/lee/Code/sitrep/bin/sitrep:2:1")
    }

    @Test func watchEndingSayingNothingGivesItsStatus() {
        #expect(Self.after(.exited(status: 0, stderr: " \n")).stale?.description == "sitrep watch ended with status 0.")
    }

    @Test func watchThatCannotStartSaysSo() {
        #expect(Self.after(.unstartable("no such file")).stale?.description == "sitrep watch could not start: no such file.")
    }

    @Test func hearingSaysWhetherWhatTheViewsShowChanged() {
        var last = LastBoard()
        let changes = [
            Heard.line(watched),
            .line(watched),
            .exited(status: 1, stderr: ""),
            .exited(status: 1, stderr: ""),
            .line(watched),
        ].map { last.hear($0) }

        #expect(changes == [true, false, true, false, true])
    }
}
