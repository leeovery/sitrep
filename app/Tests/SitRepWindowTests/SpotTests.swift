import Foundation
@testable import SitRepWindow
import Testing

/// Which of a session's two rows shows the pick, while it has an ask and so shows under Needs you and under its
/// project: the row clicked; for a pick made outside the list, the Needs you row while the ask stands, else the
/// project's; and the project's once the ask clears, the page staying. The page follows the session either way.
struct SpotTests {
    @Test(arguments: [Spot.needsYou("sr-macapp"), .board(.session("sr-macapp"))])
    func theRowClickedShowsThePickAndTheSessionsPageOpens(spot: Spot) {
        let run = opened()

        _ = run.pickInList(.board(.session("sr-rq7dgr")), at: printedAt)
        _ = run.pickInList(spot, at: printedAt)
        #expect(run.spot == spot)
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.page(at: printedAt).session?.id == "sr-macapp")
    }

    /// The window opens on the oldest session needing Lee, as a restore at launch does.
    @Test func theWindowOpeningShowsItsPickUnderNeedsYou() {
        #expect(opened().spot == .needsYou("sr-macapp"))
    }

    @Test func aPickMadeOutsideTheListShowsUnderNeedsYouWhileTheSessionHasAnAsk() {
        let run = opened()

        _ = run.pick(.session("sr-gs7kq2"))
        #expect(run.spot == .needsYou("sr-gs7kq2"))
        _ = run.pick(.session("sr-rq7dgr"))
        #expect(run.spot == .board(.session("sr-rq7dgr")))
        _ = run.pick(.project("kit"))
        #expect(run.spot == .board(.project("kit")))
    }

    /// As the menu bar opens the window on a session already showing.
    @Test func aPickMadeOutsideTheListMovesTheSelectionToNeedsYouEvenFromTheProjectsRow() {
        let run = opened()

        _ = run.pickInList(.board(.session("sr-macapp")), at: printedAt)
        _ = run.pick(.session("sr-macapp"))
        #expect(run.spot == .needsYou("sr-macapp"))
    }

    @Test func whenTheAskClearsTheSelectionMovesToTheProjectsRowAndThePageStays() {
        let run = opened()
        let page = run.page(at: printedAt).session?.id

        _ = run.pickInList(.needsYou("sr-macapp"), at: printedAt)
        _ = run.show(heard(line(0), answered("sr-macapp")), at: printedAt, reducesMotion: false)
        #expect(run.spot == .board(.session("sr-macapp")))
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.page(at: printedAt).session?.id == page)
    }

    @Test func aSessionPickedUnderItsProjectStaysThereAsTheBoardChanges() {
        let run = opened()

        _ = run.pickInList(.board(.session("sr-macapp")), at: printedAt)
        _ = run.show(heard(line(0), line(changed: ["sr-macapp"])), at: printedAt, reducesMotion: false)
        #expect(run.spot == .board(.session("sr-macapp")))
    }

    @Test func aFoldedProjectsAskShowsUnderNeedsYouAndIsPickedThere() {
        let run = opened()

        run.toggle(.project("sitrep"))
        _ = run.pickInList(.board(.session("sr-rq7dgr")), at: printedAt)
        #expect(run.sidebar(at: printedAt).lines.map(\.id).contains(.spot(.needsYou("sr-macapp"))))
        _ = run.pickInList(.needsYou("sr-macapp"), at: printedAt)
        #expect(run.spot == .needsYou("sr-macapp"))
        #expect(run.page(at: printedAt).session?.id == "sr-macapp")
    }

    /// With no `watch` to run nothing has cleared, so a session picked under Needs you stays picked there, and is
    /// there still when the board comes back.
    @Test func whenTheBoardGoesASessionPickedUnderNeedsYouStaysThere() {
        let run = opened()

        run.unrun("SitRep can't read the board")
        #expect(run.spot == .needsYou("sr-macapp"))
        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.spot == .needsYou("sr-macapp"))
    }

    @Test func aQuietProjectsRowShowsItsPickAndOpensItsPage() {
        let run = opened()

        _ = run.pickInList(.board(.project("kit")), at: printedAt)
        #expect(run.spot == .board(.project("kit")))
        #expect(run.page(at: printedAt).project?.key == "kit")
    }

    @Test func aPickGoneFromTheBoardGivesItsSpotWayWithIt() {
        let run = opened()

        _ = run.pickInList(.board(.session("sr-gs7kq2")), at: printedAt)
        _ = run.show(heard(line(0), line(3)), at: printedAt, reducesMotion: false)
        #expect(run.spot == .needsYou("sr-macapp"))
    }
}
