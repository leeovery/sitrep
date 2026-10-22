@testable import SitRepCore
import SitRepLines
import SitRepMenu
import Testing

/// What the real `sitrep watch` printed (`Lines`): a new ask on an away session, the board the window was built over,
/// and a board of rows by session.
struct RealWatchTests {
    private static let asked = heard(Lines.newAsk.map(Heard.line))

    @Test func aNewAskSendsANoticeNamingItsProjectAndSession() {
        #expect(Notices.due(Self.asked, isOn: true) == [
            Banner(title: "Choose how long the ledger keeps requests", subtitle: "Switchboard · Usage", body: "", work: nil),
        ])
    }

    @Test func theRunsFirstLineSendsNothing() {
        #expect(Notices.due(heard([.line(Lines.newAsk[0])]), isOn: true).isEmpty)
    }

    @Test func theMenuListsTheAwayAskDisabledAndTheGlyphLights() {
        let menu = MenuBoard(Self.asked, clock: london)
        let rows = menu.items.compactMap(\.session)

        #expect(menu.heading == "1 needs you")
        #expect(rows.map { $0.menuTitle(at: 0) } == ["Choose how long the ledger keeps requests"])
        #expect(rows.map(menu.jump) == [nil])
        #expect(menu.glyph == .lit)
    }

    /// Kit's window waiting on a wake due at 1_792_670_195_432, and SitRep's on three agents.
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

    @Test func theWindowsBoardListsCoresRowsWithTheHairlineUnderItsNeedsYou() {
        let menu = MenuBoard(heard([.line(Lines.watch[0])]), clock: london)

        #expect(menu.heading == "6 need you")
        #expect(menu.items.map(\.key) == ["needs:sr-macapp", "needs:sr-dash02", "needs:sr-gs7kq2", "divider", "sr-rq7dgr"])
        #expect(menu.reloads.isEmpty)
    }

    /// Harness's three asks are one item, its oldest ask then "+2"; Switchboard's ask and permission prompt one, "+1".
    @Test func aSessionWithSeveralLinesIsOneItemItsOldestThenHowManyMore() {
        let menu = MenuBoard(heard([.line(Lines.bySession[0])]), clock: london)
        let rows = menu.items.compactMap(\.session)

        #expect(menu.heading == "6 need you")
        #expect(rows.map(\.id) == ["sr-4g01a7", "sr-dash02", "sr-gs7kq2", "sr-macapp", "sr-k7bt2s", "sr-v3t7a0"])
        #expect(rows[0].menuTitle(at: 0) == "Approve the first fix batch from the branch review +2")
        #expect(rows[1].menuTitle(at: 0) == "Paste the load test's output +1")
        #expect(rows[2].menuTitle(at: 0) == "Keep the invite-by-link flow, or drop it?")
    }

    /// The fourth ask posted into Harness's session, its row's newest line: a notice of its own, naming the session.
    @Test func aNewAskInASessionWithOthersWaitingSendsANoticeOfItsOwn() {
        #expect(Notices.due(heard(Lines.bySession.map(Heard.line)), isOn: true) == [
            Banner(
                title: "Choose the branch the fixes land on", subtitle: "Harness · Finish the Harness modernisation",
                body: "", work: "sr-4g01a7"
            ),
        ])
    }
}
