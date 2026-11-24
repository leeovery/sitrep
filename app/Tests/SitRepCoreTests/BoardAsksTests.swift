import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepTestSupport
import Testing

/// Each session's open asks, as the asks panel and a new ask's banner answer them: read from the line's projects, every
/// shape of ask, a reply on its way among them, and what a line from an older CLI lacks.
@Suite(.backstop)
struct BoardAsksTests {
    /// The real CLI's line (`Lines.watch`): Trey Research's yes, choice and words ask, in the line's order.
    @Test func aSessionsAsksComeInTheLinesOrderEachWhatItWantsBack() throws {
        let board = try Board.read(Lines.watch[0])
        let asks = board.asks(of: "sr-m4h6qe")

        #expect(asks.map(\.id) == ["k2", "k3", "k1"])
        #expect(asks.map(\.wants) == [.choice, .words, .yes])
        #expect(asks.map(\.title) == [
            "Choose which page the guide opens first", "Paste the load test's output",
            "Look at round 3 of the designs and approve or comment",
        ])
        #expect(asks.map(\.at) == [1_792_468_421, 1_792_474_421, 1_792_486_181].map(Date.init(timeIntervalSince1970:)))
        expectEvery(asks, "nothing sent to any") { $0.reply == nil && $0.waitsOnLee }
    }

    @Test func aYesGivesItsButtonAndNoOptions() throws {
        let yes = try #require(try Board.read(Lines.watch[0]).ask("k1", of: "sr-m4h6qe"))

        #expect(yes.yes == "Approve")
        #expect(yes.options.isEmpty)
        #expect(yes.needs == nil)
    }

    /// A yes ask whose line gave no yes, null or left out, has core's `yesOf`'s bare `yes`, which the CLI takes.
    @Test(arguments: [#","yes":null"#, ""])
    func aYesWithNoYesGivenIsABareYes(yes: String) throws {
        let line = Self.line([WatchLine.Ask(id: "k1", wants: .yes, yes: nil)])

        #expect(line.contains(#","yes":null"#))

        let board = try Board.read(line.replacingOccurrences(of: #","yes":null"#, with: yes))

        #expect(board.ask("k1", of: "sr-nw0001")?.yes == "yes")
    }

    @Test func aChoiceGivesItsOptionsInClaudesOrderAndNoYes() throws {
        let choice = try #require(try Board.read(Lines.watch[0]).ask("k2", of: "sr-m4h6qe"))

        #expect(choice.options == ["Left, the notch's edge", "Right"])
        #expect(choice.yes == nil)
    }

    @Test func aWordsAskSaysWhatItNeeds() throws {
        let words = try #require(try Board.read(Lines.watch[0]).ask("k3", of: "sr-m4h6qe"))

        #expect(words.needs == "the command's output")
        #expect(words.yes == nil)
        #expect(words.options.isEmpty)
    }

    @Test func aChoiceSaysTheOptionClaudeRecommends() throws {
        let board = try Self.listing([
            WatchLine.Ask(
                id: "k2", wants: .choice, yes: nil, title: "Choose how the release notes are grouped",
                options: ["By package", "By change"], recommended: "By change"
            ),
        ])

        #expect(board.ask("k2", of: "sr-nw0001")?.recommended == "By change")
    }

    /// The real CLI's second line: the yes answered and the words ask ignored, both on their way, no longer waiting on
    /// Lee; the choice still is.
    @Test func anAskWhoseAnswerIsOnItsWayWaitsOnLeeNoMore() throws {
        let board = try Board.read(Lines.watch[1])
        let yes = try #require(board.ask("k1", of: "sr-m4h6qe"))

        #expect(yes.reply == Board.Ask.Reply(
            kind: .onItsWay, isAnswer: true, words: "→ Approve", since: Date(timeIntervalSince1970: 1_792_486_423.418)
        ))
        #expect(!yes.waitsOnLee)
        #expect(board.ask("k3", of: "sr-m4h6qe")?.waitsOnLee == false)
        #expect(board.ask("k2", of: "sr-m4h6qe")?.waitsOnLee == true)
    }

    /// Delivered, or not delivered, an answer is no longer on its way; an ask Lee replied to, or closed, waits on him no
    /// more.
    @Test func onlyAWaitingAskWithNoAnswerOnItsWayWaitsOnLee() throws {
        let board = try Self.listing([
            WatchLine.Ask(id: "k1", reply: .init(.delivered)),
            WatchLine.Ask(id: "k2", reply: .init(.notDelivered)),
            WatchLine.Ask(id: "k3", state: .replied),
            WatchLine.Ask(id: "k4", state: .closed),
        ])

        #expect(board.asks(of: "sr-nw0001").map(\.waitsOnLee) == [true, true, false, false])
    }

    /// The real CLI's line of 20 October 2026 (`Lines.twoAsks`), from before the watch said an ask's reply or what
    /// Claude recommends.
    @Test func anAskFromALineBeforeItsReplyAndItsRecommendationHasNeither() throws {
        let ask = try #require(try Board.read(Lines.twoAsks).ask("k1ap", of: "sr-n0tch1"))

        #expect(ask.reply == nil)
        #expect(ask.recommended == nil)
        #expect(ask.waitsOnLee)
    }

    /// An ask that does not read, as one wanting what this SitRep does not know, is left out, and the rest read.
    @Test func anAskThatDoesNotReadIsLeftOutTheRestKept() throws {
        let line = Self.line([WatchLine.Ask(id: "k1"), WatchLine.Ask(id: "k2", wants: .words, yes: nil)])
        let board = try Board.read(line.replacingOccurrences(of: #""wants":"words""#, with: #""wants":"a drawing""#))

        #expect(board.asks(of: "sr-nw0001").map(\.id) == ["k1"])
    }

    /// A session whose line carries no `asks` has none, and is named all the same.
    @Test func aSessionWhoseLineCarriesNoAsksHasNoneItsNameKept() throws {
        let line = Self.line([])

        #expect(line.contains(#""asks":[],"#))

        let board = try Board.read(line.replacingOccurrences(of: #""asks":[],"#, with: ""))

        #expect(board.asks(of: "sr-nw0001").isEmpty)
        #expect(board.name(of: "sr-nw0001") == "Ledger export")
    }

    /// A session off the board has none; an ask delivered has left the board.
    @Test func noAskIsFoundOffTheBoard() throws {
        let board = try Board.read(Lines.pretty)

        #expect(board.asks(of: "sr-zzzzzz").isEmpty)
        #expect(board.ask("k1", of: "sr-zzzzzz") == nil)
        #expect(try Board.read(Lines.watch[2]).ask("k1", of: "sr-m4h6qe") == nil, "delivered, it left the board")
    }

    /// A line of Northwind's Ledger export holding the asks given.
    private static func line(_ asks: [WatchLine.Ask]) -> String {
        WatchLine(projects: [WatchLine.Project(sessions: [WatchLine.Session(asks: asks)])]).text
    }

    private static func listing(_ asks: [WatchLine.Ask]) throws -> Board {
        try Board.read(line(asks))
    }
}
