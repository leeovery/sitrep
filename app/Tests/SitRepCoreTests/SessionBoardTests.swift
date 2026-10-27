import Foundation
@testable import SitRepCore
import SitRepLines
import Testing

/// A session's board as a line of `watch` carries it, and the asks on `watch`'s lines, read from what the real CLI
/// printed (`Lines`).
struct SessionBoardTests {
    /// The Mac app's board, as `board --json` printed it, carried on a line.
    private static func read(_ board: String) throws -> SessionBoard {
        try carried(board, of: "sr-macapp")
    }

    @Test func aSessionsBoardGivesItsProjectAndTheSessionInBrief() throws {
        let board = try Self.read(Lines.board)

        #expect(board.project == SessionBoard.Project(key: "sitrep", name: "SitRep"))
        #expect(board.session.id == "sr-macapp")
        #expect(board.session.name == "The Mac app")
        #expect(board.session.now == ["Drawing round 3, the SitRep window, in Paper", "Keeping DESIGN.md in step on docs/surfaces"])
        #expect(board.session.next == "round 4, the menu bar item and its menu")
        #expect(board.session.isOpen)
        #expect(board.session.waiting == 3)
        #expect(board.session.parked == 1)
    }

    @Test func itsAsksComeOldestFirstEachWithWhatItWantsBackAndNoReplyBeforeOneIsSent() throws {
        let asks = try Self.read(Lines.board).asks

        #expect(asks.map(\.id) == ["k2", "k3", "k1"])
        #expect(asks.map(\.wants) == [.choice, .words, .yes])
        #expect(asks[0].options == ["Left, the notch's edge", "Right"])
        #expect(asks[1].needs == "the command's output")
        #expect(asks[2].yes == "Approve")
        #expect(asks[2].where == "In Paper: SitRep · side panel, page “The SitRep window”, artboards A to C")
        #expect(asks.map(\.reply) == [nil, nil, nil])
    }

    @Test func anAnswerAndAnIgnoreInTheInboxAreOnTheirWayAsAnswersTheAskStillWaiting() throws {
        let asks = try Self.read(Lines.onItsWay).asks

        #expect(asks.map(\.state) == [.waiting, .waiting, .waiting])
        #expect(asks[1].reply?.standing == .onItsWay)
        #expect(asks[1].reply?.isAnswer == true)
        #expect(asks[1].reply?.words == "ignored")
        #expect(asks[2].reply?.standing == .onItsWay)
        #expect(asks[2].reply?.words == "→ Approve")
    }

    @Test func itsParkedItemsAndLatestLogLinesComeWithTheirTimes() throws {
        let board = try Self.read(Lines.board)

        #expect(board.parked.map(\.title) == ["Try a shy notch"])
        #expect(board.log.map(\.kind) == [.note, .note, .status])
        #expect(board.log.map(\.id) == ["n2", "n1", nil])
        #expect(board.log[0].detail == ["Under \"The strip\""])
        #expect(board.log[2].text == "Status: now drawing round 3, the SitRep window, in Paper (and 1 more)")
    }

    @Test func itsResolvedAsksComeNewestClosedFirstClosedByLeesAnswerOrByClaudeWithItsReason() throws {
        let resolved = try Self.read(Lines.board).resolved

        #expect(resolved.map(\.id) == ["k5", "k4"])
        #expect(resolved[0].reason == "you said \"left\" in the chat")
        #expect(resolved[0].ask.reply == nil)
        #expect(resolved[1].reason == nil)
        #expect(resolved[1].ask.reply?.standing == .delivered)
        #expect(resolved[1].ask.reply?.words == "→ Merge")
        #expect(resolved[1].closedAt == resolved[1].ask.reply?.since)
    }

    @Test func onceDeliveredTheYesIsResolvedByLeesAnswerAndTheIgnoredAskIsGone() throws {
        let board = try Self.read(Lines.delivered)

        #expect(board.asks.map(\.id) == ["k2"])
        #expect(board.resolved.map(\.id) == ["k1", "k5", "k4"])
        #expect(board.resolved[0].ask.state == .closed)
        #expect(board.resolved[0].ask.reply?.isAnswer == true)
    }

    @Test func aWatchLineCarriesEachSessionsAsksWithTheirReply() throws {
        let sessions = try Board.read(Lines.watch[1]).projects.flatMap(\.sessions)
        let mac = try #require(sessions.first { $0.id == "sr-macapp" })

        #expect(mac.asks.map(\.reply?.standing) == [nil, .onItsWay, .onItsWay])
        #expect(mac.waiting == 1)
    }

    @Test func aWatchLineWithAReplyTheAppDoesNotKnowIsRefused() throws {
        let line = Lines.watch[1].replacingOccurrences(of: #""is":"onItsWay""#, with: #""is":"underWay""#)

        try #require(line != Lines.watch[1])
        #expect(throws: Unread.shape) { try Board.read(line) }
    }

    @Test(arguments: [
        (#""is": "onItsWay""#, #""is": "underWay""#),
        (#""wants": "choice""#, #""wants": "pick""#),
        (#""kind": "status""#, #""kind": "edit""#),
    ])
    func aValueTheAppDoesNotKnowIsRefused(known: String, unknown: String) throws {
        let board = Lines.onItsWay.replacingOccurrences(of: known, with: unknown)

        try #require(board != Lines.onItsWay)
        #expect(throws: Unread.shape) { try Self.read(board) }
    }
}
