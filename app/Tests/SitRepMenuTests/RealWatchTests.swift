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
        #expect(rows.map(\.menuTitle) == ["Choose how long the ledger keeps requests"])
        #expect(rows.map(menu.jump) == [nil])
        #expect(menu.glyph == .lit)
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
