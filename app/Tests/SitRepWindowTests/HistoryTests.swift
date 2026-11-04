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
}
