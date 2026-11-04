import CoreGraphics
import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepPanel
import struct SitRepWindow.Listed
import Testing

/// Needs you newest first on every surface, over what the real CLI printed (`Lines.newest`): Northwind's Ledger export,
/// its asks at 09:00 and 12:00, over Contoso's Onboarding flow, its one at 11:00, though Northwind's 09:00 is the oldest
/// of all. Each row's time is its newest line's, while its session's state still counts from its oldest.
struct NewestFirstTests {
    private static let at9 = 1_793_782_800_000.0, at11 = 1_793_790_000_000.0, at12 = 1_793_793_600_000.0
    private static let order = ["sr-nw0001", "sr-ct0001"]

    private static let last: LastBoard = {
        var last = LastBoard()

        _ = last.hear(.line(Lines.newest), at: .now)
        return last
    }()

    private static func date(_ ms: Double) -> Date {
        Date(timeIntervalSince1970: ms / 1000)
    }

    private static func expectNewestFirst(_ rows: [Session]) {
        #expect(rows.map(\.id) == order)
        #expect(rows.map(\.since) == [at12, at11])
        #expect(rows.first?.lines.map(\.since) == [at12, at9])
    }

    @Test func theCardListsNorthwindFirstAtItsNewestLinesTime() {
        let items = Item.card(PanelBoard(Self.last).sessions, folds: CardFolds())

        Self.expectNewestFirst(items.compactMap(\.session))
    }

    @Test func theMenuListsNorthwindFirstAtItsNewestLinesTime() {
        Self.expectNewestFirst(MenuBoard(Self.last).items.compactMap(\.session))
    }

    /// The strip's places from its top end down: Northwind's mark over Contoso's.
    @Test func theStripPlacesNorthwindFirstAtItsNewestLinesTime() {
        let sessions = PanelBoard(Self.last).sessions
        let measure = StripMeasure(row: { _ in 200 }, rows: { _ in 200 }, idle: { 200 })
        let stage = StripStage(width: 1512, height: 982, menu: 37)
        let strip = Strip(
            length: .full, maxLength: .full, along: 0.42, sessions: sessions, measure: measure,
            StripInput(time: 0, pointer: nil, stage: stage)
        )
        let marks = strip.frame(StripInput(time: 3000, pointer: nil, stage: stage)).marks.sorted { $0.centre.y < $1.centre.y }

        #expect(marks.map(\.key) == Self.order.map(MarkKey.session))
        Self.expectNewestFirst(sessions)
    }

    @Test func theSidebarListsNorthwindFirstAtItsNewestLinesTime() {
        let rows = Listed(Self.last).rows

        #expect(rows.map(\.id) == Self.order)
        #expect(rows.map(\.since) == [Self.date(Self.at12), Self.date(Self.at11)])
    }

    /// Northwind's session has needed Lee since 09:00, its oldest line, as `watch`'s session `since` says.
    @Test func theSessionsStateStillCountsFromItsOldestLine() throws {
        let board = try #require(Self.last.board)
        let session = try #require(board.projects.first { $0.key == "northwind" }?.sessions.first)

        #expect(session.since == Self.date(Self.at9))
    }
}
