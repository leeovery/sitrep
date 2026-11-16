@testable import SitRepCore
import SitRepLines
import SitRepMenu
import Testing

/// What the real `sitrep watch` printed (`Lines`): a new ask on an away session, the board the window was built over,
/// and a board of rows by session.
struct RealWatchTests {
    private static let asked = heard(Lines.newAsk.map(Heard.line))

    /// Its click goes to the away session, for the jump to carry it on (stage 8).
    @Test func aNewAskSendsANoticeNamingItsProjectAndSession() {
        #expect(Notices.due(Self.asked, .notifyingAsks) == [
            Banner(title: "Choose how long the ledger keeps requests", subtitle: "Woodgrove · Usage", body: "", work: "sr-k3dg0r"),
        ])
    }

    @Test func theRunsFirstLineSendsNothing() {
        #expect(Notices.due(heard([.line(Lines.newAsk[0])]), .notifyingAsks).isEmpty)
    }

    @Test func theMenuListsTheAwayAskAndTheGlyphLights() {
        let menu = MenuBoard(Self.asked, clock: london)
        let rows = menu.items.compactMap(\.session)

        #expect(menu.heading == "1 needs you")
        #expect(rows.map { $0.menuTitle(at: 0) } == ["Usage"])
        #expect(rows.map(\.away) == [true])
        #expect(menu.glyph == .lit)
    }

    /// Litware's window waiting on a wake due at 1_792_670_195_432, and Trey Research's on three agents.
    @Test func aRowOnItsOwnWorkIsFaintItsSubjectPlainAndAWakeCountedDownAsItTicks() {
        let menu = MenuBoard(heard([.line(Lines.onItsWork)]), clock: london)
        let rows = menu.items.compactMap(\.session)
        let due = 1_792_670_195_432.0

        #expect(rows.map(\.kind) == [.onItsWork, .onItsWork])
        #expect(rows[0].menuLine(at: due - 690_000) == MenuTitle(words: "Wakes in 12m", mono: nil, more: nil, isFaint: true))
        #expect(rows[0].menuTitle(at: due - 30_000) == "Wakes in 1m")
        #expect(rows[0].menuTitle(at: due) == "Wakes now")
        #expect(rows[1].menuLine(at: due) == MenuTitle(words: "Waiting on 3 agents", mono: nil, more: nil, isFaint: true))
        #expect(menu.nextTick(after: due - 30_000) == due)
    }

    /// Six asks and stops and one session at Lee's turn, all of it Needs you, in core's order.
    @Test func theWindowsBoardListsItsRowsWithNoHairlineWhileNothingFollowsNeedsYou() {
        let menu = MenuBoard(heard([.line(Lines.watch[0])]), clock: london)

        #expect(menu.heading == "7 need you")
        #expect(menu.items.map(\.key) == ["needs:sr-m4h6qe", "needs:sr-d6k1vt", "needs:sr-g2r8mw", "turn:sr-rq7dgr"])
        #expect(menu.reloads.isEmpty)
    }

    /// Tailspin's three asks are one item, its session's name then "3"; Woodgrove's ask and permission prompt one,
    /// "2"; Lucerne's one away ask its name alone; then the session at Lee's turn, in Needs you, 7 needing him.
    @Test func aSessionWithSeveralLinesIsOneItemItsNameThenHowManyWait() {
        let menu = MenuBoard(heard([.line(Lines.bySession[0])]), clock: london)
        let rows = menu.items.compactMap(\.session)

        #expect(menu.heading == "7 need you")
        #expect(rows.map(\.id) == ["sr-4t2kq8", "sr-d6k1vt", "sr-g2r8mw", "sr-v9d2wj", "sr-m4h6qe", "sr-k7bt2s"])
        #expect(rows[0].menuTitle(at: 0) == "Finish the Tailspin migration 3")
        #expect(rows[1].menuTitle(at: 0) == "Dashboard redesign 2")
        #expect(rows[2].menuTitle(at: 0) == "Onboarding")
        #expect(rows.prefix(3).map(\.sub) == ["Tailspin", "Woodgrove", "No window holds it. Carry it on in Claude."])
    }

    /// The fourth ask posted into Tailspin's session, its row's newest line: a notice of its own, naming the session.
    @Test func aNewAskInASessionWithOthersWaitingSendsANoticeOfItsOwn() {
        #expect(Notices.due(heard(Lines.bySession.map(Heard.line)), .notifyingAsks) == [
            Banner(
                title: "Choose the branch the fixes land on", subtitle: "Tailspin · Finish the Tailspin migration",
                body: "", work: "sr-4t2kq8"
            ),
        ])
    }
}
