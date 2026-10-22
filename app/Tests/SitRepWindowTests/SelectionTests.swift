import Foundation
@testable import SitRepWindow
import Testing

/// The sidebar's selection: each session shows once, so the pick is its row, which keeps it as it moves between
/// sections; a pick made outside the list unfolds what would hide it, so it shows; a fold made over the pick hides
/// its row and keeps its page.
struct SelectionTests {
    private static func ids(_ run: WindowRun) -> [Sidebar.Line.ID] {
        run.sidebar(at: printedAt).lines.map(\.id)
    }

    @Test func theRowClickedIsThePickAndItsSessionsPageOpens() {
        let run = opened()

        _ = run.pickInList(.session("sr-rq7dgr"), at: printedAt)
        #expect(run.pick == .session("sr-rq7dgr"))
        #expect(run.page(at: printedAt).session?.id == "sr-rq7dgr")
        #expect(run.sidebar(at: printedAt).picks.contains(.session("sr-rq7dgr")))
    }

    /// Request ledger's turn ends on an ask: its row leaves Your turn for Needs you, the same row, still picked.
    @Test func aSessionKeepsItsPickAsItMovesBetweenSections() throws {
        let run = opened()

        _ = run.pickInList(.session("sr-rq7dgr"), at: printedAt)
        _ = run.show(heard(line(0), asked("sr-rq7dgr")), at: printedAt, reducesMotion: false)

        let ids = Self.ids(run)
        let row = try #require(ids.firstIndex(of: .pick(.session("sr-rq7dgr"))))

        #expect(run.pick == .session("sr-rq7dgr"))
        #expect(row < ids.firstIndex(of: .fold(.projects))!)
        #expect(!ids.contains(.fold(.section(.yourTurn))))
        #expect(run.page(at: printedAt).session?.id == "sr-rq7dgr")
    }

    /// As the menu, a jump or a restore at launch picks it.
    @Test func aPickMadeOutsideTheListUnfoldsTheSectionHoldingIt() {
        let run = opened()

        run.toggle(.section(.yourTurn))
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
        _ = run.pick(.session("sr-rq7dgr"))
        #expect(!run.folds.contains(.section(.yourTurn)))
        #expect(Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
    }

    /// The window opening on the oldest session needing Lee, Needs you folded when it last closed.
    @Test func theWindowOpeningOnASessionUnfoldsItsSection() {
        var folds = Folds()

        folds.toggle(.section(.needsYou))

        let run = WindowRun(folds: folds, wall: { printedAt })

        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        _ = run.open()
        #expect(run.pick == .session("sr-macapp"))
        #expect(!run.folds.contains(.section(.needsYou)))
    }

    /// An hour on, Request ledger's turn has passed the fold period.
    @Test func aPickMadeOutsideTheListUnderNEarlierOpensIt() {
        let run = opened(wall: { printedAt.addingTimeInterval(3600) })

        #expect(Self.ids(run).contains(.fold(.earlier)))
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
        _ = run.pick(.session("sr-rq7dgr"))
        #expect(run.folds.isEarlierOpen)
        #expect(Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
    }

    /// A project's name pressed on a session's page: Projects unfolds, and the project's row is the pick.
    @Test func aProjectsPageShowsPickedOnItsRowInProjects() {
        let run = opened()

        #expect(run.folds.projects)
        _ = run.pick(.project("switchboard"))
        #expect(!run.folds.projects)
        #expect(run.sidebar(at: printedAt).lines.contains { $0.pick == run.pick })
        #expect(run.page(at: printedAt).project?.key == "switchboard")
    }

    @Test func aProjectsRowClickedOpensItsPage() {
        let run = opened()

        run.toggle(.projects)
        _ = run.pickInList(.project("kit"), at: printedAt)
        #expect(run.pick == .project("kit"))
        #expect(run.page(at: printedAt).project?.key == "kit")
    }

    /// Projects folded over a project's page: nothing in the list shows the pick, and the page stays.
    @Test func foldingTheSectionThatHoldsThePickKeepsThePage() {
        let run = opened()

        _ = run.pickInList(.session("sr-rq7dgr"), at: printedAt)
        run.toggle(.section(.yourTurn))
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
        #expect(run.pick == .session("sr-rq7dgr"))
        #expect(run.page(at: printedAt).session?.id == "sr-rq7dgr")

        _ = run.pick(.project("kit"))
        run.toggle(.projects)
        #expect(!run.sidebar(at: printedAt).lines.contains { $0.pick == .project("kit") })
        #expect(run.page(at: printedAt).project?.key == "kit")
    }

    /// While the filter holds text the list shows open; a pick made then leaves Lee's folds as they were.
    @Test func aPickMadeWhileFilteringChangesNoneOfLeesFolds() {
        let run = opened()

        run.toggle(.section(.yourTurn))
        run.filter = Filter("ledg")
        _ = run.pick(.session("sr-rq7dgr"))
        #expect(run.folds.contains(.section(.yourTurn)))
    }

    @Test func aPickInTheListUnfoldsNothing() {
        let run = opened()
        let folds = run.folds

        _ = run.pickInList(.session("sr-dash02"), at: printedAt)
        #expect(run.folds == folds)
    }

    /// With no `watch` to run nothing has cleared, so the pick stays, and is there still when the board comes back.
    @Test func whenTheBoardGoesThePickStays() {
        let run = opened()

        run.unrun("SitRep can't read the board")
        #expect(run.pick == .session("sr-macapp"))
        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.pick == .session("sr-macapp"))
    }
}
