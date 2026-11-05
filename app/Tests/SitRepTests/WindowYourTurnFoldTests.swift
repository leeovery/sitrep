import Foundation
@testable import SitRep
import SitRepLines
@testable import SitRepWindow
import Testing

/// The window's Your turn folds its rows past an hour under "N earlier", a period of its own since Settings' "Your turn
/// folds after" went with the card's "N earlier" (board J2, 4 November 2026).
@MainActor
struct WindowYourTurnFoldTests {
    /// `watch`'s last line in `Lines.snoozedTurn`: three turns, all ended on 4 November 2026 by 19:20, so over an hour
    /// before any run of this test.
    @Test func yourTurnFoldsRowsPastAnHourUnderNEarlier() throws {
        let model = try WindowModel.made()

        model.show(HostedSidebar.heard(Lines.snoozedTurn[2]))
        model.opened()
        model.actions.click(.place(.yourTurn))

        let list = try #require(model.list)

        #expect(list.rows.isEmpty)
        #expect(list.fold?.kind == .earlier)
        #expect(list.fold?.rows.map(\.session) == ["sr-nwtrn5", "sr-ctnbd2", "sr-fbrk3m"])
    }
}
