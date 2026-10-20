import Foundation
@testable import SitRepCore
@testable import SitRepWindow
import Testing

struct WordsTests {
    @Test func theStateLinesTimeSaysHowLongTheTurnHasRunOrSinceItEnded() {
        let since = printedAt.addingTimeInterval(-360)

        #expect(Words.turn(doing(.working, "Writing", since: since), at: printedAt) == "· 6m into this turn")
        #expect(Words.turn(doing(.working, "Writing", since: printedAt), at: printedAt) == "· this turn just began")
        #expect(Words.turn(doing(.yourTurn, "Writing", since: since), at: printedAt) == "· its turn ended 6m ago")
        #expect(Words.turn(doing(.yourTurn, "Writing", since: printedAt), at: printedAt) == "· its turn just ended")
        #expect(Words.turn(doing(.permission, "Allow Bash", since: since), at: printedAt) == nil)
        #expect(Words.turn(doing(.away, "No window holds it.", since: since), at: printedAt) == nil)
    }

    @Test func aYesIsInClaudesWordsAndWhatNeedsClaudesPromptSaysItLeavesSitRep() {
        #expect(Words.button(.yes("Approve")) == "✓ Approve")
        #expect(Words.button(.option("Keep it")) == "Keep it")
        #expect(Words.button(.inClaude(.comment)) == "Comment in Claude ↗")
        #expect(Words.button(.inClaude(.answer)) == "Answer in Claude ↗")
        #expect(Words.button(.ignore) == "Ignore")
    }

    @Test func aCardSaysWhereItsAnswerIsInThePanesWords() {
        let pending = Pending(answer: .words("Approve"), pressed: printedAt, stage: .waiting)

        #expect(Words.line(.waiting(pending)) == ("→ Approve", "sending · Esc to undo"))
        #expect(Words.line(.onItsWay("→ Approve", .turn)) == ("→ Approve", "on its way: waits for the turn to end"))
        #expect(Words.line(.onItsWay("→ Approve", .none)) == ("→ Approve", "on its way"))
        #expect(Words.line(.closed(.sent)) == (nil, "sent, and Claude has it"))
    }

    @Test func aClosedAskSaysHowItClosed() {
        #expect(Words.closed(.resolved("you said \"left\" in the chat")) == "resolved by Claude: you said \"left\" in the chat")
        #expect(Words.closed(.resolved(nil)) == "resolved by Claude")
        #expect(Words.closed(.ignored) == "ignored")
    }

    @Test func aProjectSaysWhatWaitsThereAndHowManyOfItsSessionsAreOpen() {
        #expect(Words.project(waiting: 2, open: 2) == "2 waiting on you, in 2 open sessions")
        #expect(Words.project(waiting: 0, open: 1) == "Nothing waiting on you, in 1 open session")
        #expect(Words.project(waiting: 1, open: 0) == "1 waiting on you, and no session open")
    }

    @Test func finishingAsksFirstNamingTheSession() {
        #expect(Words.finishing("Settle the older open questions") == "Finish Settle the older open questions? Its open asks stop counting.")
    }
}
