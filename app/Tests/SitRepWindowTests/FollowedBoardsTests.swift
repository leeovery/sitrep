import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// A session's first board, `watch` carrying boards as the real CLI does (`Watching`): followed without a break, a
/// session's board as kept is current, so a page made for it has that board for its first, and what changes after is
/// washed or kept in place; followed afresh, `watch` carries its board anew, and that first board lays its asks out.
struct FollowedBoardsTests {
    /// Dashboard redesign's words ask, k1, closed, and another, k9, posted.
    private static let changed = edited(Lines.dashboard) { board in
        let asks = board["asks"] as! [[String: Any]]

        board["asks"] = [asks[0].merging(["id": "k9", "title": "Paste the second load test's output"]) { $1 }]
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

    private static func asks(_ run: WindowRun) -> [String] {
        let page = run.page(at: later)
        let cards = page.session?.asks ?? page.project?.asks.map(\.card) ?? []

        return cards.filter { $0.id.session == "sr-dash02" }.map { card in
            [card.id.ask, card.washed == later ? "washed" : nil, card.isClosed ? "closed" : nil]
                .compactMap { $0 }.joined(separator: " ")
        }
    }

    /// The project's page follows both its sessions; picking one follows it alone, which `watch` carries nothing for.
    @Test func aSessionPickedFromItsProjectsPageHasItsBoardAsKeptForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(on: .project("switchboard")) }
        watching.after { $0.pick(.session("sr-dash02")) }
        #expect(Self.asksAsTheyChange(watching) == Self.washedAndKept)
    }

    /// The project's page follows its other session too, which `watch` carries, and nothing more of the one picked.
    @Test func aSessionsProjectOpenedFromItsPageHasItsBoardAsKeptForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(on: .session("sr-dash02")) }
        watching.after { $0.pick(.project("switchboard")) }
        #expect(Self.asksAsTheyChange(watching) == Self.washedAndKept)
    }

    /// The first pick is followed at once; the next two, a run, leave it standing, and the run ends where it began.
    @Test func aRunOfPicksInTheListEndingOnTheSessionItStoodOnHasItsBoardAsKeptForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(on: .session("sr-macapp")) }
        watching.after { $0.pickInList(.session("sr-dash02"), at: printedAt) }
        watching.after { $0.pickInList(.session("sr-rq7dgr"), at: printedAt.addingTimeInterval(0.1)) }
        watching.after { $0.pickInList(.session("sr-dash02"), at: printedAt.addingTimeInterval(0.2)) }
        watching.after { $0.settle(at: printedAt.addingTimeInterval(0.2 + PickFollows.settle)) }
        #expect(Self.asksAsTheyChange(watching) == Self.washedAndKept)
    }

    /// What changed while another page showed comes on the board `watch` carries anew as the session is followed
    /// again: Lee saw neither come nor go.
    @Test func aSessionFollowedAgainHasTheBoardWatchCarriesAnewForItsFirst() {
        let watching = Watching()

        watching.after { $0.open(on: .session("sr-dash02")) }
        watching.after { $0.pick(.session("sr-macapp")) }
        watching.change("sr-dash02", to: Self.changed)
        overThePage(watching.run, at: Self.later)
        watching.after({ $0.pick(.session("sr-dash02")) }, at: Self.later)
        #expect(Self.asks(watching.run) == ["k9"])
    }

    /// `watch` down, its boards as kept stay current, so a page made meanwhile has its board as kept for its first,
    /// and what changed while it was down, on the board the next run carries, is washed or kept in place, as on a page
    /// that showed throughout.
    @Test func aBoardKeptFromTheRunBeforeIsCurrentUntilTheNextRunCarriesItAgain() {
        let watching = Watching()

        watching.after { $0.open(on: .project("switchboard")) }
        watching.ends(at: printedAt)
        watching.after { $0.pick(.session("sr-dash02")) }
        watching.change("sr-dash02", to: Self.changed)
        overThePage(watching.run, at: Self.later)
        watching.startsAgain(at: Self.later)
        #expect(Self.asks(watching.run) == Self.washedAndKept)
    }
}
