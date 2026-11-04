@testable import SitRepWindow
import Testing

/// Back and Forward: where Lee goes pushes, a change within the list replaces.
struct HistoryTests {
    private static let needsYou = Location.place(.needsYou)
    private static let kit = Location.project("kit")
    private static let pushed = Location.session("sr-k7t001", from: .project("kit"))
    private static let picked = Location.place(
        .needsYou, picked: Selection(pick: .line("ask:sr-macapp:k2"), session: "sr-macapp")
    )

    @Test func itBeginsWithNothingBackOrForward() {
        let history = History(Self.needsYou)

        #expect(history.location == Self.needsYou)
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
    }

    /// A sidebar click, project → session, a breadcrumb link, "later · N parked", "N parked", "Back to its
    /// session" and an open from outside each push; a change of what the list picked replaces.
    @Test func everyWayButAChangeWithinTheListPushes() {
        #expect(History.Way.allCases.filter(\.pushes) == [
            .sidebar, .projectSession, .breadcrumb, .sessionParked, .projectParked, .backToSession, .outside,
        ])
        #expect(!History.Way.list.pushes)
    }

    @Test func goingSomewhereThatPushesLetsBackReturn() {
        for way in History.Way.allCases where way.pushes {
            var history = History(Self.needsYou)

            history.go(to: Self.kit, by: way)
            #expect(history.location == Self.kit)
            #expect(history.canGoBack)

            history.goBack()
            #expect(history.location == Self.needsYou)
            #expect(history.canGoForward)
        }
    }

    /// Picking another row replaces the step: Back skips every row picked, to where Lee came from.
    @Test func aChangeWithinTheListReplacesTheStep() {
        var history = History(Self.kit)

        history.go(to: Self.needsYou, by: .sidebar)
        history.go(to: Self.picked, by: .list)

        #expect(history.location == Self.picked)
        history.goBack()
        #expect(history.location == Self.kit)
        history.goForward()
        #expect(history.location == Self.picked)
    }

    @Test func pushingLetsGoOfWhatLayForward() {
        var history = History(Self.needsYou)

        history.go(to: Self.kit, by: .sidebar)
        history.go(to: Self.pushed, by: .projectSession)
        history.goBack()
        history.go(to: Self.needsYou, by: .sidebar)

        #expect(!history.canGoForward)
        history.goBack()
        #expect(history.location == Self.kit)
        history.goBack()
        #expect(history.location == Self.needsYou)
        #expect(!history.canGoBack)
    }

    /// Clicking the place the window is on again makes no step to go back over.
    @Test func goingWhereTheWindowIsPushesNothing() {
        var history = History(Self.needsYou)

        history.go(to: Self.needsYou, by: .sidebar)

        #expect(!history.canGoBack)
    }

    /// The board leaving the window elsewhere, as a pushed session finishing, makes no step either; and where it
    /// leaves it on the step before, that step goes, so Back never stays put.
    @Test func aReplaceMakesNoStep() {
        var history = History(Self.needsYou)

        history.go(to: Self.kit, by: .sidebar)
        history.go(to: Self.pushed, by: .projectSession)
        history.replace(with: Self.kit)

        #expect(history.location == Self.kit)
        history.goBack()
        #expect(history.location == Self.needsYou)
        #expect(!history.canGoBack)
    }

    @Test func backAndForwardWithNowhereToGoStayPut() {
        var history = History(Self.needsYou)

        history.goBack()
        history.goForward()

        #expect(history.location == Self.needsYou)
    }

    /// Replacing where the window is with the step Back left ahead drops that step, so Forward never stays put.
    @Test func aReplaceOntoTheStepAheadDropsIt() {
        var history = History(Self.kit)

        history.go(to: Self.pushed, by: .projectSession)
        history.goBack()
        history.replace(with: Self.pushed)

        #expect(history.location == Self.pushed)
        #expect(!history.canGoForward)
    }

    /// Goosemates' session finishes, its project going with it, while the window is on that project's page with
    /// Kit's ahead: the window opens afresh on Needs you's first line; the session's page ahead, and the project it
    /// would give way to, go; Kit's stays, so Forward lands on it, and then has nowhere left.
    @Test func onABoardChangeEveryStepIsKeptAsItStands() {
        let goosemates = Location.project("goosemates")
        var history = History(Self.needsYou)

        history.go(to: goosemates, by: .sidebar)
        history.go(to: .session("sr-gs7kq2", from: .project("goosemates")), by: .projectSession)
        history.go(to: Self.kit, by: .sidebar)
        history.goBack()
        history.goBack()
        history.keep(on: Listed(heard(line(3))))

        #expect(history.location == Self.picked)
        history.goForward()
        #expect(history.location == Self.kit)
        #expect(!history.canGoForward)
        history.goBack()
        history.goBack()
        #expect(history.location == Self.needsYou)
        #expect(!history.canGoBack)
    }

    /// Two steps that come to be the same, as a session's page giving way to the place it was pushed from beside
    /// that place, are one.
    @Test func stepsThatComeToBeTheSameAreOne() {
        var history = History(.place(.parked))

        history.go(to: .session("sr-gs7kq2", from: .place(.parked)), by: .backToSession)
        history.go(to: Self.kit, by: .sidebar)
        history.keep(on: Listed(heard(line(3))))
        history.goBack()

        #expect(history.location == .place(.parked))
        #expect(!history.canGoBack)
    }

    /// Northwind's two lines and Contoso's between them, Contoso's picked; the sidebar goes to Northwind's page, and
    /// Contoso's ask is answered meanwhile. Back returns to Needs you as it was, so ↓ goes to the row after the
    /// answered one, not to the top.
    @Test func backReturnsToThePickStandingWhereItWas() throws {
        let northwind = Built(id: "s1", project: "northwind", waiting: [30, 20])
        var contoso = Built(id: "s2", project: "contoso", waiting: [25])
        let before = PlaceList(.needsYou, in: Built.listed([northwind, contoso]))
        var history = History(.place(.needsYou, picked: try before.picked(.line(contoso.line(0)))))

        history.go(to: .project("northwind"), by: .sidebar)
        contoso.waiting = []
        contoso.state = .yourTurn

        let after = Built.listed([northwind, contoso])

        history.keep(on: after)
        history.goBack()

        #expect(PlaceList(.needsYou, in: after).step(from: history.location.picked, down: true) == .line(northwind.line(1)))
    }
}
