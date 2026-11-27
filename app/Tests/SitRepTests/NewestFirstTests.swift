import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

/// Needs you newest first on every surface, over what the real CLI printed (`Lines.newest`): Northwind's Ledger export,
/// its asks at 09:00 and 12:00, over Contoso's Onboarding flow, its one at 11:00, though Northwind's 09:00 is the oldest
/// of all. Each row's time is its newest line's.
@Suite(.backstop)
struct NewestFirstTests {
    private static let at9 = 1_793_782_800_000.0, at11 = 1_793_790_000_000.0, at12 = 1_793_793_600_000.0
    private static let order = ["sr-nw0001", "sr-ct0001"]

    private static let last: LastBoard = {
        var last = LastBoard()

        _ = last.hear(.line(Lines.newest), at: .now)
        return last
    }()

    private static func expectNewestFirst(_ rows: [Session], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rows.map(\.id) == order, sourceLocation: sourceLocation)
        #expect(rows.map(\.since) == [at12, at11], sourceLocation: sourceLocation)
        #expect(rows.first?.lines.map(\.since) == [at12, at9], sourceLocation: sourceLocation)
    }

    @Test func theCardListsNorthwindFirstAtItsNewestLinesTime() {
        let items = Item.card(PanelBoard(Self.last).sessions, folds: CardFolds())

        Self.expectNewestFirst(items.compactMap(\.session))
    }

    @Test func theMenuListsNorthwindFirstAtItsNewestLinesTime() {
        Self.expectNewestFirst(MenuBoard(Self.last).items.compactMap(\.session))
    }
}
