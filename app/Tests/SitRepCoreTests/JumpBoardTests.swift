import Foundation
@testable import SitRepCore
import Testing

/// The board a jump goes from: the watch's last line, waited for where none has come yet, or why none will.
@MainActor
struct JumpBoardTests {
    /// A look of the watch that heard the line given.
    private static func heard(_ line: String) -> LastBoard {
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(line), at: Date())
        return last
    }

    @Test func aBoardHeardIsGivenAtOnceAndKeptThoughTheWatchGoesStale() async throws {
        let jumpBoard = JumpBoard()
        var last = Self.heard(watched)

        jumpBoard.heard(last)
        _ = last.hear(.exited(.status(1), stderr: ""), at: Date())
        jumpBoard.heard(last)
        jumpBoard.unrun("No plugin to run.")

        #expect(await jumpBoard.current() == .board(try Board.read(watched)))
    }

    @Test func aJumpAskedForBeforeTheFirstLineWaitsForIt() async throws {
        let jumpBoard = JumpBoard()
        let waiting = Task { await jumpBoard.current() }

        await Task.yield()
        jumpBoard.heard(LastBoard())
        jumpBoard.heard(Self.heard(watched))

        #expect(await waiting.value == .board(try Board.read(watched)))
    }

    @Test func withNoLineTheWatchHeardFailingOrNoPluginToRunItIsWhyThereIsNone() async {
        let failed = JumpBoard(), unrun = JumpBoard()
        var last = LastBoard()

        _ = last.hear(.unstartable("no Bun"), at: Date())
        failed.heard(last)
        unrun.unrun("SitRep has no plugin to run.")

        #expect(await failed.current() == .unread(Stale.unstartable("no Bun").description))
        #expect(await unrun.current() == .unread("SitRep has no plugin to run."))
    }

    @Test func aBoardHeardAfterWhyThereWasNoneTakesItsPlace() async throws {
        let jumpBoard = JumpBoard()

        jumpBoard.unrun("SitRep has no plugin to run.")
        jumpBoard.heard(Self.heard(watched))

        #expect(await jumpBoard.current() == .board(try Board.read(watched)))
    }
}
