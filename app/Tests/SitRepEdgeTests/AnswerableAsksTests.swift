import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The asks the asks panel answers, as the board gives them to the panel (DESIGN, "Answering from the panel"): each
/// Needs you row's asks, taken from its lines in their order, each timed as its line is; a yes by its one button, a
/// choice by its options and Claude's pick, a words ask, or a choice with no options, answered in Claude; and none for
/// a row of Claude Code's own prompts, nor for a turn's or a working row.
@Suite(.backstop)
struct AnswerableAsksTests {
    private static let board = AsksBoard.board()

    @Test func aRowsAsksAreItsLinesAsksInTheirOrderTimedAsTheirLines() throws {
        let asks = try #require(Self.board.asks[AsksBoard.helpDesk])

        #expect(asks.map(\.id) == ["k1", "k2"])
        #expect(asks.map(\.since) == [AsksBoard.ago(4), AsksBoard.ago(12)].map(Double.init))
        #expect(asks.map(\.title) == ["Thread replies, or keep them flat?", "Review Tickets & Replies, round 1"])
    }

    @Test func aChoiceOffersItsOptionsAndItsPickAndAYesItsButton() throws {
        let asks = try #require(Self.board.asks[AsksBoard.helpDesk])

        #expect(asks[0].answers == ["Threaded", "Flat"] && asks[0].recommended == "Threaded")
        #expect(asks[1].answers == ["Approve"] && asks[1].recommended == nil)
        #expect(!asks[0].isInClaude && !asks[1].isInClaude)
    }

    @Test func aWordsAskIsAnsweredInClaude() throws {
        let asks = try #require(Self.board.asks[AsksBoard.shifts])

        #expect(asks.map(\.id) == ["k1"])
        #expect(asks[0].isInClaude && asks[0].answers.isEmpty)
    }

    @Test func aChoiceWithNoOptionsIsAnsweredInClaudeAndAPickNotOfferedIsNone() {
        #expect(PanelAsk(id: "k1", title: "Pick", answers: [], since: 0).isInClaude)
        #expect(PanelAsk(id: "k1", title: "Pick", answers: ["A"], recommended: "B", since: 0).recommended == nil)
    }

    /// Invoice ledger waits on a permission prompt alone; Onboarding flow is at Lee's turn; the others work.
    @Test func noRowButAnAsksHasAny() {
        #expect(Set(Self.board.asks.keys) == [AsksBoard.helpDesk, AsksBoard.shifts])
    }

    @Test func anAskTheRowsLinesNoLongerShowIsNone() {
        #expect(AsksBoard.board(without: ["k1"]).asks[AsksBoard.helpDesk]?.map(\.id) == ["k2"])
    }

    @Test func theAgeReadsAsTheRowsTime() {
        let ask = PanelAsk(id: "k1", title: "Pick", since: 0)

        #expect(ask.askedText(at: 30_000) == "Asked just now")
        #expect(ask.askedText(at: 4 * 60_000) == "Asked 4m ago")
        #expect(ask.askedText(at: 2 * 3_600_000) == "Asked 2h ago")
        #expect(ask.ageChanges(after: 30_000) == 60_000)
    }
}
