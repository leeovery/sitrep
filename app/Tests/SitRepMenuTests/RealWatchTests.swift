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
        #expect(Notices.due(Self.asked, isOn: true) == [
            Banner(title: "Choose how long the ledger keeps requests", subtitle: "Switchboard · Usage", body: "", work: "sr-k3dg0r"),
        ])
    }

    @Test func theRunsFirstLineSendsNothing() {
        #expect(Notices.due(heard([.line(Lines.newAsk[0])]), isOn: true).isEmpty)
    }

    @Test func theMenuListsTheAwayAskAndTheGlyphLights() {
        let menu = MenuBoard(Self.asked, clock: london)
        let rows = menu.items.compactMap(\.session)

        #expect(menu.heading == "1 needs you")
        #expect(rows.map { $0.menuTitle(at: 0) } == ["Usage"])
        #expect(rows.map(\.away) == [true])
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

    @Test func theWindowsBoardListsCoresRowsWithNoHairlineWhileNothingFollowsWhatWaitsOnLee() {
        let menu = MenuBoard(heard([.line(Lines.watch[0])]), clock: london)

        #expect(menu.heading == "6 need you")
        #expect(menu.items.map(\.key) == ["needs:sr-macapp", "needs:sr-dash02", "needs:sr-gs7kq2", "turn:sr-rq7dgr"])
        #expect(menu.reloads.isEmpty)
    }

    /// Harness's three asks are one item, its session's name then "3"; Switchboard's ask and permission prompt one,
    /// "2"; Goosemates' one away ask its name alone.
    @Test func aSessionWithSeveralLinesIsOneItemItsNameThenHowManyWait() {
        let menu = MenuBoard(heard([.line(Lines.bySession[0])]), clock: london)
        let rows = menu.items.compactMap(\.session)

        #expect(menu.heading == "6 need you")
        #expect(rows.map(\.id) == ["sr-4g01a7", "sr-dash02", "sr-gs7kq2", "sr-macapp", "sr-k7bt2s", "sr-v3t7a0"])
        #expect(rows[0].menuTitle(at: 0) == "Finish the Harness modernisation 3")
        #expect(rows[1].menuTitle(at: 0) == "Dashboard redesign 2")
        #expect(rows[2].menuTitle(at: 0) == "Onboarding")
        #expect(rows.prefix(3).map(\.sub) == ["Harness", "Switchboard", "No window holds it. Carry it on in Claude."])
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
