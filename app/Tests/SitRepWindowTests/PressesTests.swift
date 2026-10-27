import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// Which of the window's buttons shows a jump under way: only the one pressed, one jump at a time.
struct JumpingTests {
    private static let first = JumpPress.card(AskAddress(session: "sr-boot", ask: "k1"), .inClaude(.comment))
    private static let second = JumpPress.card(AskAddress(session: "sr-boot", ask: "k2"), .inClaude(.comment))

    @Test func onlyTheButtonPressedShowsTheJump() {
        var jumping = Jumping()
        let jumped = jumping.press(Self.first, isJumping: false)

        #expect(jumped)
        #expect(jumping.pressed == Self.first)
        #expect(jumping.pressed != Self.second)
    }

    @Test func aSecondPressWhileTheJumpRunsStartsNoneAndLeavesTheFirstShowing() {
        var jumping = Jumping()

        _ = jumping.press(Self.first, isJumping: false)

        let beforeItRuns = jumping.press(Self.second, isJumping: false)
        let whileItRuns = jumping.press(Self.second, isJumping: true)

        #expect(!beforeItRuns)
        #expect(!whileItRuns)
        #expect(jumping.pressed == Self.first)
    }

    @Test func aPressWhileAnotherSurfacesJumpRunsStartsNoneAndShowsNothing() {
        var jumping = Jumping()
        let jumped = jumping.press(.open("sr-boot"), isJumping: true)

        #expect(!jumped)
        #expect(jumping.pressed == nil)
    }

    @Test func theJumpAnsweredTheButtonShowsAsItDidAndTheNextPressJumps() {
        var jumping = Jumping()

        _ = jumping.press(Self.first, isJumping: false)
        jumping.answered()
        #expect(jumping.pressed == nil)

        let next = jumping.press(.stop("sr-boot"), isJumping: false)

        #expect(next)
    }

    @Test func eachPressJumpsToItsSession() {
        #expect(Self.first.session == "sr-boot")
        #expect(JumpPress.open("sr-macapp").session == "sr-macapp")
        #expect(JumpPress.stop("sr-dash02").session == "sr-dash02")
    }
}

/// A quiet project's row in Projects: it opens its project, as any project's does.
struct QuietProjectTests {
    @Test func aQuietProjectOpensOnItsSessionsNoneOfThemInAWindow() throws {
        let run = opened()
        let pick = try #require(run.listed(at: printedAt).projects.first { $0.name == "Kit" }?.pick)

        run.pick(pick)
        #expect(run.following == ["sr-k7t001"])

        let page = try #require(run.page(at: printedAt).project)

        #expect(page.name == "Kit")
        #expect(page.open == 0)
        #expect(page.sessions.map(\.isAway) == [true])
    }
}

/// An item of Status, Notes, Parked or Resolved opens in place to the whole of it, and closes again.
struct OpenedItemsTests {
    @Test func aPressOpensAnItemAndASecondClosesIt() throws {
        let run = opened()

        run.toggle(.note("sr-macapp:n2"))
        #expect(try #require(run.page(at: printedAt).session).opened == [.note("sr-macapp:n2")])
        run.toggle(.note("sr-macapp:n2"))
        #expect(try #require(run.page(at: printedAt).session).opened.isEmpty)
    }

    @Test func itemsOpenEachOnTheirOwn() throws {
        let run = opened()

        run.toggle(.status(0, Self.drawing))
        run.toggle(.resolved("k4"))
        #expect(try #require(run.page(at: printedAt).session).opened == [.status(0, Self.drawing), .resolved("k4")])
    }

    @Test func anItemGoneFromThePageIsLetGoAndCannotOpenAgainByItsKey() throws {
        let run = opened()
        let rewritten = Lines.watch[0].replacingOccurrences(of: Self.drawing, with: "Drawing round 4")

        run.toggle(.status(0, Self.drawing))
        run.show(heard(.line(rewritten)), at: printedAt, reducesMotion: false)
        #expect(try #require(run.page(at: printedAt).session).opened.isEmpty)
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(try #require(run.page(at: printedAt).session).status.now.first == Self.drawing)
        #expect(try #require(run.page(at: printedAt).session).opened.isEmpty)
    }

    @Test func twoStatusLinesAlikeAreTwoItems() {
        #expect(Item.status(0, Self.drawing) != Item.status(1, Self.drawing))
    }

    private static let drawing = "Drawing round 3, the SitRep window, in Paper"

    @Test func pickingAnotherPageClosesThemAll() throws {
        let run = opened()

        run.toggle(.parked("p1"))
        run.pick(.project("sitrep"))
        #expect(try #require(run.page(at: printedAt).project).opened.isEmpty)
    }

    @Test func aProjectsPageOpensItsItemsToo() throws {
        let run = opened()

        run.pick(.project("sitrep"))
        run.toggle(.parked("sr-macapp:p1"))
        #expect(try #require(run.page(at: printedAt).project).opened == [.parked("sr-macapp:p1")])
    }

    @Test func aNoteOpenedShowsItsDetail() throws {
        let page = try #require(opened().page(at: printedAt).session)

        #expect(page.notes.first?.detail == [#"Under "The strip""#])
    }

    @Test func aResolvedAskOpensToHowItClosedAndLeesAnswerWhereHisAnswerClosedIt() throws {
        let page = try #require(opened().page(at: printedAt).session)
        let answered = try #require(page.resolved.first { $0.id == "k4" })
        let byClaude = try #require(page.resolved.first { $0.id == "k5" })

        #expect(Words.howClosed(answered).answer == "→ Merge")
        #expect(Words.howClosed(answered).words == "sent, and Claude has it")
        #expect(Words.howClosed(byClaude).answer == nil)
        #expect(Words.howClosed(byClaude).words == #"resolved by Claude: you said "left" in the chat"#)
    }

    /// An item with more than its line is a button; one with nothing more is one only while its line is cut short,
    /// which only its layout knows.
    @Test func aNoteWithDetailAParkedItemWithAPlaceAndEveryResolvedAskOpenToMore() throws {
        let page = try #require(opened(boards: ["sr-macapp": Self.parkedWithAPlace]).page(at: printedAt).session)

        #expect(page.notes.map(\.hasMore) == [true, false, true])
        #expect(page.parked.map(\.hasMore) == [true])
        #expect(page.resolved.map(\.hasMore) == [true, true])
    }

    @Test func aParkedItemWithNoPlaceOpensToNothingMore() throws {
        let page = try #require(opened().page(at: printedAt).session)

        #expect(page.parked.map(\.hasMore) == [false])
    }

    private static let parkedWithAPlace = Lines.board
        .replacingOccurrences(of: #""title": "Try a shy notch",\#n      "where": null"#, with: #""title": "Try a shy notch",\#n      "where": "In DESIGN.md, under The notch""#)
}

/// A card's buttons as pills on one line while they fit at their one-line width, else its answers as rows.
struct ArrangementTests {
    private static let choice: [Card.Button] = [.option("Left"), .option("Right"), .inClaude(.comment), .ignore]

    @Test func buttonsThatFitOnOneLineStayPills() {
        #expect(Card.arrangement(of: Self.choice, widths: [60, 60, 140, 60], spacing: 8, in: 344) == .pills)
    }

    @Test func buttonsPastTheLineByAPointLayTheAnswersOutAsRows() {
        #expect(Card.arrangement(of: Self.choice, widths: [60, 60, 140, 60], spacing: 8, in: 343) == .rows([0, 1]))
    }

    @Test func oneLongOptionAmongShortOnesMakesThemAllRows() {
        #expect(Card.arrangement(of: Self.choice, widths: [520, 60, 140, 60], spacing: 8, in: 700) == .rows([0, 1]))
    }

    @Test func aYesTooLongForTheLineIsARowToo() {
        let yes: [Card.Button] = [.yes("Merge it"), .inClaude(.comment), .ignore]

        #expect(Card.arrangement(of: yes, widths: [600, 140, 60], spacing: 8, in: 700) == .rows([0]))
    }

    @Test func aCardWithNoAnswerToGiveHereThatOverflowsLaysEveryButtonOutAsARow() {
        let words: [Card.Button] = [.inClaude(.answer), .ignore]

        #expect(Card.arrangement(of: words, widths: [150, 60], spacing: 8, in: 300) == .pills)
        #expect(Card.arrangement(of: words, widths: [250, 60], spacing: 8, in: 300) == .rows([0, 1]))
    }

    @Test func whereTheRestOverflowTheirLineTooEveryButtonIsARow() {
        #expect(Card.arrangement(of: Self.choice, widths: [400, 60, 200, 120], spacing: 8, in: 300) == .rows([0, 1, 2, 3]))
    }

    @Test func aRowIsAsWideAsItsWordsNeverTheCards() {
        #expect(Card.rowWidth(120, in: 700) == 120)
        #expect(Card.rowWidth(480, in: 700) == 480)
    }

    @Test func aRowWrapsOnlyPast480OrTheCardWhereThatIsNarrower() {
        #expect(Card.rowWidth(620, in: 700) == 480)
        #expect(Card.rowWidth(450, in: 400) == 400)
    }
}
