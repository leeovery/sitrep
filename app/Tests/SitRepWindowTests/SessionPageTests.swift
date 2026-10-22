import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// The session on the right, from what the real CLI printed: what its window is doing, its asks as cards, and the
/// rest of its board.
struct SessionPageTests {
    private static func page(_ run: WindowRun, at time: Date = printedAt) throws -> SessionPage {
        try #require(run.page(at: time).session)
    }

    private static func card(_ ask: String, _ run: WindowRun, at time: Date = printedAt) throws -> Card {
        try #require(page(run, at: time).asks.first { $0.id.ask == ask })
    }

    private static func picked(_ session: String, boards: [String: String]) -> WindowRun {
        let run = opened(boards: boards)

        answer(run.pick(.session(session)), in: run, with: boards)
        return run
    }

    // MARK: The head of the page

    @Test func itSaysItsProjectItsNameAndSummaryAndOffersTheJumpWhileAWindowHoldsIt() throws {
        let page = try Self.page(opened())

        #expect(page.projectKey == "sitrep")
        #expect(page.projectName == "SitRep")
        #expect(page.name == "The Mac app")
        #expect(page.summary == "SitRep, the menu bar app: the notch, the strip and this window")
        #expect(page.jumps)
        #expect(page.finish == nil)
    }

    @Test func theStateLineIsWhatWatchSaysTheSessionIsDoingThoughNoRowOfItsWindowsShows() throws {
        let page = try Self.page(opened())

        #expect(page.doing == doing(.working, "Writing", mono: ".scratch/step-back.md", since: minutes(before: 6)))
    }

    @Test func aPermissionPromptTakesTheStateLinesPlace() throws {
        let page = try Self.page(Self.picked("sr-dash02", boards: [:]))

        #expect(page.doing == doing(.permission, "Allow Bash", mono: "gh pr create --draft --base main", since: minutes(before: 1)))
        #expect(page.doing.isStopped)
    }

    @Test func yourTurnSaysWhatItsRowSays() throws {
        let page = try Self.page(Self.picked("sr-rq7dgr", boards: [:]))

        #expect(page.doing == doing(.yourTurn, "Drawing the ledger schema", since: minutes(before: 12)))
    }

    @Test func anAwaySessionHasNoJumpAndOffersToFinishIt() throws {
        let page = try Self.page(Self.picked("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))

        #expect(page.doing == doing(.away, "No window holds it. Carry it on in Claude.", since: minutes(before: 1440)))
        #expect(!page.jumps)
        #expect(page.finish == .offered)
    }

    @Test func beforeItsBoardIsReadItSaysSoAndShowsNoAsks() throws {
        let page = try Self.page(opened(boards: [:]))

        #expect(!page.isRead)
        #expect(page.failure == nil)
        #expect(page.asks.isEmpty)
    }

    @Test func itsJumpItsFinishAndItsButtonsFollowWhatWatchSaysItIsDoingTheOneFactOfAway() throws {
        let away = try Self.page(opened(on: heard(line(with: "sr-macapp", doing: .away))))

        #expect(!away.jumps)
        #expect(away.finish == .offered)
        #expect(away.asks.first { $0.id.ask == "k1" }?.buttons == [.yes("Approve"), .ignore])

        let run = opened(on: heard(line(with: "sr-gs7kq2", doing: .yourTurn)))

        answer(run.pick(.session("sr-gs7kq2")), in: run, with: ["sr-gs7kq2": Lines.away])

        let held = try Self.page(run)

        #expect(held.jumps)
        #expect(held.finish == nil)
        #expect(held.asks.first?.buttons.contains(.inClaude(.comment)) == true)
        #expect(run.listed(at: printedAt).rows.first { $0.id == "sr-gs7kq2" }?.isAway == false)
    }

    // MARK: The cards

    @Test func itsAsksShowTheNewestFirst() throws {
        #expect(try Self.page(opened()).asks.map(\.id.ask) == ["k1", "k3", "k2"])
    }

    @Test func aYesIsAPillInClaudesWordsBesideACommentInClaudeAndIgnore() throws {
        let yes = try Self.card("k1", opened())

        #expect(yes.buttons == [.yes("Approve"), .inClaude(.comment), .ignore])
        #expect(yes.where == "In Paper: SitRep · side panel, page “The SitRep window”, artboards A to C")
        #expect(yes.lines.isEmpty)
    }

    @Test func aChoiceIsAPillPerOption() throws {
        #expect(try Self.card("k2", opened()).buttons == [
            .option("Left, the notch's edge"), .option("Right"), .inClaude(.comment), .ignore,
        ])
    }

    @Test func aWordsAskIsAnsweredInClaudeAndSaysWhatItsWordsAre() throws {
        let words = try Self.card("k3", opened())

        #expect(words.buttons == [.inClaude(.answer), .ignore])
        #expect(words.needs == "the command's output")
    }

    @Test func onAnAwaySessionAYesOrAChoiceWaitsInTheInboxAndNothingNeedsClaudesPrompt() throws {
        let choice = try Self.card("k1", Self.picked("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))

        #expect(choice.buttons == [.option("Keep it"), .option("Drop it"), .ignore])
        #expect(choice.lines == [.inbox])
    }

    @Test func anAnswerOnItsWayTakesTheButtonsAwaySayingItWaitsForTheTurnToEnd() throws {
        let run = opened(boards: ["sr-macapp": Lines.onItsWay])
        let yes = try Self.card("k1", run)

        #expect(yes.buttons.isEmpty)
        #expect(yes.lines == [.onItsWay("→ Approve", .turn)])
    }

    @Test func onAnAwaySessionAnAnswerOnItsWayWaitsForAWindow() throws {
        let windowless = Lines.watch[0].replacingOccurrences(of: #""doing":{"is":"working""#, with: #""doing":{"is":"away""#)
        let run = opened(on: heard(.line(windowless)), boards: ["sr-macapp": Lines.onItsWay])

        #expect(try Self.card("k1", run).lines == [.onItsWay("→ Approve", .window)])
    }

    @Test func aCommentOnItsWayBarsNoAnswerSoTheButtonsStay() throws {
        let comment = Lines.onItsWay
            .replacingOccurrences(of: #""isAnswer": true,"# + "\n" + #"        "words": "→ Approve""#, with: #""isAnswer": false,"# + "\n" + #"        "words": "comment: “Tighten it”""#)
        let run = opened(boards: ["sr-macapp": comment])
        let yes = try Self.card("k1", run)

        try #require(comment != Lines.onItsWay)
        #expect(yes.buttons == [.yes("Approve"), .inClaude(.comment), .ignore])
        #expect(yes.lines == [.commentOnItsWay("comment: “Tighten it”")])
    }

    // MARK: The rest of the board

    @Test func itsStatusNotesAndParkedComeFromItsBoard() throws {
        let page = try Self.page(opened())

        #expect(page.status.now == ["Drawing round 3, the SitRep window, in Paper", "Keeping DESIGN.md in step on docs/surfaces"])
        #expect(page.status.next == "round 4, the menu bar item and its menu")
        #expect(page.status.updated == minutes(before: 1100))
        #expect(page.notes.map(\.text) == ["The strip written into DESIGN.md", "PR #4 merged", "Status: now drawing round 3, the SitRep window, in Paper (and 1 more)"])
        #expect(page.parked.map(\.title) == ["Try a shy notch"])
        #expect(page.waiting == 3)
    }

    @Test func resolvedSaysHowEachClosed() throws {
        let page = try Self.page(opened())

        #expect(page.resolved.map(\.title) == ["Look at round 1, the panel's rows", "Merge PR #4"])
        #expect(page.resolved.map(\.how) == [.resolved("you said \"left\" in the chat"), .sent])
    }
}
