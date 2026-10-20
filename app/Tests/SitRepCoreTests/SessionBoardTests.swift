import Foundation
@testable import SitRepCore
import SitRepLines
import Testing

/// `board --json` and the asks on `watch`'s lines, read from what the real CLI printed (`Lines`).
struct SessionBoardTests {
    private static func at(_ milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / 1000)
    }

    @Test func aSessionsBoardGivesItsProjectAndTheSessionInBrief() throws {
        let board = try SessionBoard.read(Lines.board)

        #expect(board.project == SessionBoard.Project(key: "sitrep", name: "SitRep"))
        #expect(board.work.id == "sr-macapp")
        #expect(board.work.name == "The Mac app")
        #expect(board.work.now == ["Drawing round 3, the SitRep window, in Paper", "Keeping DESIGN.md in step on docs/surfaces"])
        #expect(board.work.next == "round 4, the menu bar item and its menu")
        #expect(board.work.isOpen)
        #expect(board.work.waiting == 3)
        #expect(board.work.parked == 1)
    }

    @Test func itsAsksComeOldestFirstEachWithWhatItWantsBackAndNoReplyBeforeOneIsSent() throws {
        let asks = try SessionBoard.read(Lines.board).asks

        #expect(asks.map(\.id) == ["k2", "k3", "k1"])
        #expect(asks.map(\.wants) == [.choice, .words, .yes])
        #expect(asks[0].options == ["Left, the notch's edge", "Right"])
        #expect(asks[1].needs == "the command's output")
        #expect(asks[2].yes == "Approve")
        #expect(asks[2].where == "In Paper: SitRep · side panel, page “The SitRep window”, artboards A to C")
        #expect(asks.map(\.reply) == [nil, nil, nil])
    }

    @Test func anAnswerAndAnIgnoreInTheInboxAreOnTheirWayAsAnswersTheAskStillWaiting() throws {
        let asks = try SessionBoard.read(Lines.onItsWay).asks

        #expect(asks.map(\.state) == [.waiting, .waiting, .waiting])
        #expect(asks[1].reply?.standing == .onItsWay)
        #expect(asks[1].reply?.isAnswer == true)
        #expect(asks[1].reply?.words == "ignored")
        #expect(asks[2].reply?.standing == .onItsWay)
        #expect(asks[2].reply?.words == "→ Approve")
    }

    @Test func itsParkedItemsAndLatestLogLinesComeWithTheirTimes() throws {
        let board = try SessionBoard.read(Lines.board)

        #expect(board.parked.map(\.title) == ["Try a shy notch"])
        #expect(board.log.map(\.kind) == [.note, .note, .status])
        #expect(board.log.map(\.id) == ["n2", "n1", nil])
        #expect(board.log[0].detail == ["Under \"The strip\""])
        #expect(board.log[2].text == "Status: now drawing round 3, the SitRep window, in Paper (and 1 more)")
    }

    @Test func itsResolvedAsksComeNewestClosedFirstClosedByLeesAnswerOrByClaudeWithItsReason() throws {
        let resolved = try SessionBoard.read(Lines.board).resolved

        #expect(resolved.map(\.id) == ["k5", "k4"])
        #expect(resolved[0].reason == "you said \"left\" in the chat")
        #expect(resolved[0].ask.reply == nil)
        #expect(resolved[1].reason == nil)
        #expect(resolved[1].ask.reply?.standing == .delivered)
        #expect(resolved[1].ask.reply?.words == "→ Merge")
        #expect(resolved[1].closedAt == resolved[1].ask.reply?.since)
    }

    @Test func onceDeliveredTheYesIsResolvedByLeesAnswerAndTheIgnoredAskIsGone() throws {
        let board = try SessionBoard.read(Lines.delivered)

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

    @Test func aBoardOfAnotherVersionSaysSo() {
        let older = Lines.board.replacingOccurrences(of: #""v": 2"#, with: #""v": 1"#)

        #expect(throws: Unread.version(given: 1, read: 2)) { try SessionBoard.read(older) }
    }

    @Test(arguments: [
        (#""is": "onItsWay""#, #""is": "underWay""#),
        (#""wants": "choice""#, #""wants": "pick""#),
        (#""kind": "status""#, #""kind": "edit""#),
    ])
    func aValueTheAppDoesNotKnowIsRefused(known: String, unknown: String) throws {
        let line = Lines.onItsWay.replacingOccurrences(of: known, with: unknown)

        try #require(line != Lines.onItsWay)
        #expect(throws: Unread.shape) { try SessionBoard.read(line) }
    }
}
