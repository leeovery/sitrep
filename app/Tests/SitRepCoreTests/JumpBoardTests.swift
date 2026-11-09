import Foundation
@testable import SitRepCore
import Testing

/// The board a jump goes from: the last line of a watch running and printed, waited for while the watch starts, starts
/// again or is stale; at once why none will come with no plugin to run it.
@MainActor
struct JumpBoardTests {
    /// A look of a watch run that printed the line given.
    private static func heard(_ line: String) -> LastBoard {
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(line), at: Date())
        return last
    }

    /// The look after the one given that heard what is given.
    private static func after(_ last: LastBoard, _ heard: Heard) -> LastBoard {
        var after = last

        _ = after.hear(heard, at: Date())
        return after
    }

    /// A jump that asks once the task has run to its wait.
    private static func asking(_ jumpBoard: JumpBoard) async -> Task<JumpBoard.Read, Never> {
        let asking = Task { await jumpBoard.current() }

        for _ in 0..<100 {
            await Task.yield()
        }
        return asking
    }

    @Test func theBoardOfAWatchRunningAndPrintedIsGivenAtOnce() async throws {
        let jumpBoard = JumpBoard()

        jumpBoard.heard(Self.heard(watched))

        #expect(await jumpBoard.current() == .board(try Board.read(watched)))
    }

    @Test func aJumpAskedForBeforeTheFirstLineWaitsForIt() async throws {
        let jumpBoard = JumpBoard()
        let waiting = await Self.asking(jumpBoard)

        jumpBoard.heard(LastBoard())
        jumpBoard.heard(Self.heard(watched))

        #expect(await waiting.value == .board(try Board.read(watched)))
    }

    /// A stale board is not jumped from: the jump waits for the watch, started again, to print.
    @Test(arguments: [
        Heard.exited(.status(1), stderr: "sitrep: EACCES: permission denied\n"),
        .unstartable("no Bun"),
        .line("not a board"),
    ])
    func aJumpAskedForWhileTheWatchIsStaleWaitsForItsNextLine(stale: Heard) async throws {
        let jumpBoard = JumpBoard()
        let staled = Self.after(Self.heard(watched), stale)

        jumpBoard.heard(staled)

        let waiting = await Self.asking(jumpBoard)
        var started = staled

        started.begin()
        _ = started.hear(.line(watchedEmpty), at: Date())
        jumpBoard.heard(started)

        #expect(await waiting.value == .board(try Board.read(watchedEmpty)))
    }

    @Test func withNoPluginToRunTheWatchAJumpIsToldWhyAtOnceUntilAWatchRuns() async throws {
        let jumpBoard = JumpBoard()

        jumpBoard.unrun("SitRep has no plugin to run.")
        #expect(await jumpBoard.current() == .unread("SitRep has no plugin to run."))

        jumpBoard.heard(Self.heard(watched))
        #expect(await jumpBoard.current() == .board(try Board.read(watched)))
    }

    @Test func aJumpWaitingAsTheWatchGivesUpForWantOfAPluginIsToldWhy() async {
        let jumpBoard = JumpBoard()
        let waiting = await Self.asking(jumpBoard)

        jumpBoard.unrun("SitRep has no plugin to run.")

        #expect(await waiting.value == .unread("SitRep has no plugin to run."))
    }

    /// A wait whose jump is stopped, by its limit or a later click, ends at once with why the board is not there,
    /// leaving none behind: a board heard after reaches nobody.
    @Test func aWaitCancelledEndsAtOnceSayingWhyTheBoardIsNotThere() async {
        let jumpBoard = JumpBoard()
        let waiting = await Self.asking(jumpBoard)

        waiting.cancel()

        #expect(await waiting.value == .unread("SitRep has no board yet: sitrep watch has printed none."))
        jumpBoard.heard(Self.heard(watched))
    }

    @Test func whyTheBoardIsNotThereIsTheWatchsWordsAsTheViewsSayThemElseThatItHasPrintedNone() {
        let jumpBoard = JumpBoard()
        let stale = Self.after(Self.heard(watched), .exited(.status(1), stderr: ""))

        #expect(jumpBoard.missing() == "SitRep has no board yet: sitrep watch has printed none.")

        jumpBoard.heard(stale)
        #expect(jumpBoard.missing() == "SitRep can't read the board: \(Stale.exited(.status(1), said: nil))")
        #expect(jumpBoard.missing() == "SitRep can't read the board: sitrep watch ended with status 1.")
    }
}
