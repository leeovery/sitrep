import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// A session's first board, `watch` carrying boards as the real CLI does (`Watching`): followed without a break, a
/// session's board as kept is current, so a page made for it has that board for its first, and what changes after is
/// washed or kept in place; followed afresh, `watch` carries its board anew, and that first board lays its asks out.
struct FollowedBoardsTests {
    /// When k9 is posted, after the board was seeded, in milliseconds: the newest ask.
    private static let posted = 1_792_486_500_000

    /// Dashboard redesign's words ask, k1, closed, and another, k9, posted.
    private static let changed = edited(Lines.dashboard) { board in
        let asks = board["asks"] as! [[String: Any]]

        board["asks"] = [asks[0].merging(["id": "k9", "title": "Paste the second load test's output", "at": Self.posted]) { $1 }]
    }

    private static let later = printedAt.addingTimeInterval(5)

    /// k9 new at the top, washed, and k1 closed in its place, as the pointer is over the page.
    private static let washedAndKept = ["k9 washed", "k1 closed"]

    /// Dashboard redesign's asks as the page shows them once its board changes, later, the pointer over the page:
    /// each by its id, and washed or closed where it is.
    private static func asksAsTheyChange(_ watching: Watching) -> [String] {
        overThePage(watching.run, at: later)
        watching.change("sr-dash02", to: changed, at: later)
        return asks(watching.run)
    }

    /// A session's asks as the page shows them at this time, each by its id, and washed from then or closed where it
    /// is.
    private static func asks(_ run: WindowRun, of session: String = "sr-dash02", at time: Date = later) -> [String] {
        let cards = run.page(at: time).session?.asks ?? []

        return cards.filter { $0.id.session == session }.map { card in
            [card.id.ask, card.washed == time ? "washed" : nil, card.isClosed ? "closed" : nil]
                .compactMap { $0 }.joined(separator: " ")
        }
    }

    /// The project's page follows both its sessions; picking one follows it alone, which `watch` carries nothing for.
    @Test func aSessionPickedFromItsProjectsPageHasItsBoardAsKeptForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(); $0.click(.project("switchboard")) }
        watching.after { $0.go(to: .session("sr-dash02", from: .project("switchboard")), by: .projectSession) }
        #expect(Self.asksAsTheyChange(watching) == Self.washedAndKept)
    }

    /// The project's page follows its other session too, which `watch` carries, and nothing more of the one picked, so
    /// the session pushed from it again has its board as kept for its first.
    @Test func aSessionsProjectOpenedFromItsPageHasItsBoardAsKeptForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(); $0.land("sr-dash02") }
        watching.after { $0.click(.project("switchboard")) }
        watching.after { $0.go(to: .session("sr-dash02", from: .project("switchboard")), by: .projectSession) }
        #expect(Self.asksAsTheyChange(watching) == Self.washedAndKept)
    }

    /// The first pick is followed at once; the next two, a run, leave it standing, and the run ends where it began.
    @Test func aRunOfPicksInTheListEndingOnTheSessionItStoodOnHasItsBoardAsKeptForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(); $0.land("sr-macapp") }
        watching.after { $0.pickInList(.line("ask:sr-dash02:k1"), at: printedAt) }
        watching.after { $0.pickInList(.line("ask:sr-macapp:k2"), at: printedAt.addingTimeInterval(0.1)) }
        watching.after { $0.pickInList(.line("ask:sr-dash02:k1"), at: printedAt.addingTimeInterval(0.2)) }
        watching.after { $0.settle(at: printedAt.addingTimeInterval(0.2 + PickFollows.settle)) }
        #expect(Self.asksAsTheyChange(watching) == Self.washedAndKept)
    }

    /// What changed while another page showed comes on the board `watch` carries anew as the session is followed
    /// again: Lee saw neither come nor go.
    @Test func aSessionFollowedAgainHasTheBoardWatchCarriesAnewForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(); $0.land("sr-dash02") }
        watching.after { $0.land("sr-macapp") }
        watching.change("sr-dash02", to: Self.changed)
        overThePage(watching.run, at: Self.later)
        watching.after({ $0.land("sr-dash02") }, at: Self.later)
        #expect(Self.asks(watching.run) == ["k9"])
    }

    /// The Mac app's choice, k1, retitled; then k1 closed and another, k9, posted.
    private static let retitled = Lines.board.replacingOccurrences(
        of: #""title": "Look at round 3, the SitRep window, and approve it or comment""#,
        with: #""title": "Look at round 4, the SitRep window, and approve it or comment""#
    )
    private static let replaced = edited(retitled) { board in
        let asks = board["asks"] as! [[String: Any]]

        board["asks"] = asks.filter { $0["id"] as? String != "k1" } + [asks[0].merging(["id": "k9", "at": Self.posted]) { $1 }]
    }

    /// `watch`'s first line with Dashboard redesign finished, off the board: in no row and no project.
    private static let dashboardFinished = edited(Lines.watch[0]) { board in
        board["rows"] = (board["rows"] as! [[String: Any]]).filter { $0["session"] as? String != "sr-dash02" }
        board["projects"] = (board["projects"] as! [[String: Any]]).map { project in
            project.merging(["sessions": (project["sessions"] as! [[String: Any]]).filter { $0["id"] as? String != "sr-dash02" }]) { $1 }
        }
    }

    /// A line printed under a set the window has since left, heard after the set told in its place: the Mac app's
    /// board on it came while the Mac app was not told, so it is not current, though the line has the window pick
    /// the Mac app again, Dashboard redesign gone from the board. Its project's page, picked before `watch` carries
    /// the Mac app anew, has no first board, nor has the Mac app pushed from it, and that board, changed since, lays its
    /// asks out.
    @Test func aBoardOnALineHeardAfterItsSessionWasLetGoOfIsNotCurrent() {
        let watching = Watching()

        watching.after { $0.open(); $0.land("sr-macapp") }
        watching.isHolding = true
        watching.change("sr-macapp", to: Self.retitled, line: Self.dashboardFinished)
        watching.after { $0.land("sr-dash02") }
        watching.change("sr-macapp", to: Self.replaced)
        watching.lands(1)
        watching.after { $0.click(.project("sitrep")) }
        watching.after { $0.go(to: .session("sr-macapp", from: .project("sitrep")), by: .projectSession) }
        overThePage(watching.run)
        watching.lands()
        #expect(Self.asks(watching.run, of: "sr-macapp", at: printedAt) == ["k9", "k3", "k2"])
    }

    /// `watch` down, its boards as kept stay current, so a page made meanwhile has its board as kept for its first,
    /// and what changed while it was down, on the board the next run carries, is washed or kept in place, as on a page
    /// that showed throughout.
    @Test func aBoardKeptFromTheRunBeforeIsCurrentUntilTheNextRunCarriesItAgain() {
        let watching = Watching()

        watching.after { $0.open(); $0.click(.project("switchboard")) }
        watching.ends(at: printedAt)
        watching.after { $0.land("sr-dash02") }
        watching.change("sr-dash02", to: Self.changed)
        overThePage(watching.run, at: Self.later)
        watching.startsAgain(at: Self.later)
        #expect(Self.asks(watching.run) == Self.washedAndKept)
    }
}
