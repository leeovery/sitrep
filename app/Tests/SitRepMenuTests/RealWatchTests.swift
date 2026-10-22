@testable import SitRepCore
import SitRepLines
import SitRepMenu
import Testing

/// What the real `sitrep watch` printed (`Lines`): a new ask on an away session, and the board the window was built
/// over.
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
        #expect(menu.items.map(\.key) == [
            "ask:sr-macapp:k2", "ask:sr-macapp:k3", "ask:sr-dash02:k1", "ask:sr-macapp:k1",
            "stop:sr-dash02:w2:1792486361000", "ask:sr-gs7kq2:k1", "divider", "turn:sr-rq7dgr",
        ])
        #expect(menu.reloads.isEmpty)
    }
}
