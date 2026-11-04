import Foundation
@testable import SitRepWindow
import Testing

/// Back and Forward: where Lee goes pushes, a change within the list replaces, and the board keeps every step as it
/// stands, the list's pick standing where it showed.
struct HistoryTests {
    private static let needsYou = Location.place(.needsYou)
    private static let kit = Location.project("kit")
    private static let pushed = Location.session("sr-k7t001", from: .project("kit"))
    private static let k2 = Selection(pick: .line("ask:sr-macapp:k2"), session: "sr-macapp")
    private static let picked = Location.place(.needsYou, picked: k2)
    /// Needs you's first line on `watch`'s first and last lines: Switchboard's stop, the newest.
    private static let newest = Location.place(
        .needsYou, picked: Selection(pick: .line("stop:sr-dash02:w2:1792486361000"), session: "sr-dash02")
    )

    /// Northwind's two lines, 30 and 20 minutes old, and Contoso's between them, 25.
    private static let northwind = Built(id: "s1", project: "northwind", waiting: [30, 20])
    private static let contoso = Built(id: "s2", project: "contoso", waiting: [25])

    private static func answered(_ session: Built) -> Built {
        var answered = session

        answered.waiting = []
        answered.state = .yourTurn
        return answered
    }

    /// The board taken, each place's list as `watch` orders it.
    private static func keep(_ history: inout History, on listed: Listed) {
        history.keep(on: listed) { PlaceList($0, in: listed) }
    }

    /// Where ↓ goes in Needs you on this board from what the history has picked.
    private static func down(_ history: History, on listed: Listed) -> ListPick? {
        PlaceList(.needsYou, in: listed).step(from: history.location.picked, down: true)?.pick
    }

    @Test func itBeginsWithNothingBackOrForward() {
        let history = History(Self.needsYou)

        #expect(history.location == Self.needsYou)
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
    }

    /// A sidebar click, project → session, a breadcrumb link, "later N parked", "N parked", "Back to its
    /// session" and an open from outside each make a step Back returns from.
    @Test func everyWayOfGoingSomewherePushes() {
        #expect(History.Way.allCases == [
            .sidebar, .projectSession, .breadcrumb, .sessionParked, .projectParked, .backToSession, .outside,
        ])
        for way in History.Way.allCases {
            var history = History(Self.needsYou)

            history.go(to: Self.kit, by: way)
            #expect(history.location == Self.kit)
            history.goBack()
            #expect(history.location == Self.needsYou)
            #expect(history.canGoForward)
        }
    }

    /// Picking another row replaces the step: Back skips every row picked, to where Lee came from.
    @Test func aChangeWithinTheListReplacesTheStep() {
        var history = History(Self.kit)

        history.go(to: Self.needsYou, by: .sidebar)
        history.pick(Self.k2)

        #expect(history.location == Self.picked)
        history.goBack()
        #expect(history.location == Self.kit)
        history.goForward()
        #expect(history.location == Self.picked)
    }

    /// A page with no list has nothing to pick.
    @Test func aPickOnAPageWithNoListIsRefused() {
        var history = History(Self.kit)

        history.pick(Self.k2)

        #expect(history.location == Self.kit)
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

    /// A pick that comes to be the step before, or the step Back left ahead, drops that step, so neither Back nor
    /// Forward stays put.
    @Test func aPickOntoTheStepBeforeOrAheadDropsIt() {
        var before = History(Self.needsYou)
        var ahead = History(Self.needsYou)

        before.go(to: Self.picked, by: .outside)
        before.pick(nil)
        ahead.go(to: Self.picked, by: .outside)
        ahead.goBack()
        ahead.pick(Self.k2)

        #expect(before.location == Self.needsYou)
        #expect(!before.canGoBack)
        #expect(ahead.location == Self.picked)
        #expect(!ahead.canGoForward)
    }

    @Test func backAndForwardWithNowhereToGoStayPut() {
        var history = History(Self.needsYou)

        history.goBack()
        history.goForward()

        #expect(history.location == Self.needsYou)
    }

    // MARK: Opens from outside

    /// Kit's away session has no row: its project's page, then the session's over it, two steps, as if Lee had gone
    /// there himself, so Back goes to Kit's page; already on Kit's page, one.
    @Test func anOpenFromOutsideWithNoRowIsTheProjectThenTheSession() {
        let listed = Listed(heard(line(0)))
        var elsewhere = History(Self.needsYou)
        var onKit = History(Self.kit)

        let landedElsewhere = elsewhere.land(Location.opening(session: "sr-k7t001", on: listed))
        let landedOnKit = onKit.land(Location.opening(session: "sr-k7t001", on: listed))

        #expect(landedElsewhere && landedOnKit)
        #expect(elsewhere.location == Self.pushed)
        elsewhere.goBack()
        #expect(elsewhere.location == Self.kit)
        elsewhere.goBack()
        #expect(elsewhere.location == Self.needsYou)
        onKit.goBack()
        #expect(onKit.location == Self.kit)
        #expect(!onKit.canGoBack)
    }

    /// Before a board is heard an open from outside lands nowhere yet, to be tried again.
    @Test func anOpenFromOutsideAwaitingABoardLandsNowhere() {
        var history = History(Self.needsYou)

        let landed = history.land(Location.opening(session: "sr-macapp", on: Listed()))

        #expect(!landed)
        #expect(history.location == Self.needsYou)
    }

    // MARK: A cold open

    /// The window opens on Kit's page, where it was left, before `watch`'s first line; the first board has lines
    /// waiting, so the window opens on Needs you's first line, as it would have with the board.
    @Test func aColdOpenTakesTheOpeningRuleWithTheFirstBoard() {
        var history = History(opening: Listed(), remembered: Self.kit)

        #expect(history.location == Self.kit)
        Self.keep(&history, on: Listed(heard(line(0))))
        #expect(history.location == Self.newest)
        #expect(!history.canGoBack)
    }

    /// Left on Working with a session since on Lee's turn, nothing waiting: Working, nothing picked; and Lee having
    /// gone somewhere before the first board, the board leaves him there.
    @Test func aColdOpenDropsAPickItsListNoLongerListsAndLeavesAStepTaken() {
        let turned = Built(id: "w1", project: "northwind", state: .yourTurn)
        let working = Location.place(.working, picked: Selection(pick: .session("w1"), session: "w1"))
        var history = History(opening: Listed(), remembered: working)
        var moved = History(opening: Listed(), remembered: Self.kit)

        Self.keep(&history, on: Built.listed([turned]))
        moved.go(to: .project("sitrep"), by: .sidebar)
        Self.keep(&moved, on: Listed(heard(line(0))))

        #expect(history.location == .place(.working))
        #expect(moved.location == .project("sitrep"))
    }

    // MARK: The board changing

    /// Goosemates' session finishes, its project going with it, while the window is on that project's page with
    /// Kit's ahead: the window opens afresh on Needs you's first line; the session's page ahead, and the project it
    /// would give way to, go; Kit's stays, so Forward lands on it, and then has nowhere left.
    @Test func onABoardChangeEveryStepIsKeptAsItStands() {
        var history = History(Self.needsYou)

        history.go(to: .project("goosemates"), by: .sidebar)
        history.go(to: .session("sr-gs7kq2", from: .project("goosemates")), by: .projectSession)
        history.go(to: Self.kit, by: .sidebar)
        history.goBack()
        history.goBack()
        Self.keep(&history, on: Listed(heard(line(3))))

        #expect(history.location == Self.newest)
        history.goForward()
        #expect(history.location == Self.kit)
        #expect(!history.canGoForward)
        history.goBack()
        history.goBack()
        #expect(history.location == Self.needsYou)
        #expect(!history.canGoBack)
    }

    /// Two steps that come to be the same, as a session's page giving way to the place it was pushed from beside
    /// that place, are one; and the window given way to it makes no step of its own.
    @Test func stepsThatComeToBeTheSameAreOne() {
        var history = History(Self.needsYou)

        history.go(to: .place(.parked), by: .sidebar)
        history.go(to: .session("sr-gs7kq2", from: .place(.parked)), by: .backToSession)
        Self.keep(&history, on: Listed(heard(line(3))))

        #expect(history.location == .place(.parked))
        history.goBack()
        #expect(history.location == Self.needsYou)
        #expect(!history.canGoBack)
    }

    /// With no board, as `watch` stopping, every step stays.
    @Test func withNoBoardEveryStepStays() {
        var history = History(Self.needsYou)

        history.go(to: Self.pushed, by: .sidebar)
        Self.keep(&history, on: Listed(unrun: "sitrep watch stopped"))

        #expect(history.location == Self.pushed)
        #expect(history.canGoBack)
    }

    // MARK: Where the pick stood

    /// Contoso's line picked; the sidebar goes to Northwind's page, and Contoso's ask is answered meanwhile. Back
    /// returns to Needs you as it was, so ↓ goes to the row after the answered one, not to the top.
    @Test func backReturnsToThePickStandingWhereItWas() throws {
        let before = PlaceList(.needsYou, in: Built.listed([Self.northwind, Self.contoso]))
        let after = Built.listed([Self.northwind, Self.answered(Self.contoso)])
        var history = History(.place(.needsYou, picked: try before.picked(.line(Self.contoso.line(0)))))

        history.go(to: .project("northwind"), by: .sidebar)
        Self.keep(&history, on: after)
        history.goBack()

        #expect(Self.down(history, on: after) == .line(Self.northwind.line(0)))
    }

    /// Opened from outside on Contoso's line, which then leaves: ↓ goes to the row after it.
    @Test func anOpenFromOutsideStandsWhereItLanded() {
        let after = Built.listed([Self.northwind, Self.answered(Self.contoso)])
        var history = History(Self.kit)

        history.land(Location.opening(session: "s2", on: Built.listed([Self.northwind, Self.contoso])))
        Self.keep(&history, on: after)

        #expect(Self.down(history, on: after) == .line(Self.northwind.line(0)))
    }

    /// Northwind's newer line picked, ↓ to Contoso's, which then leaves: ↓ goes on to Northwind's older.
    @Test func aPickMadeByAnArrowStandsWhereItWasMade() throws {
        let before = PlaceList(.needsYou, in: Built.listed([Self.northwind, Self.contoso]))
        let after = Built.listed([Self.northwind, Self.answered(Self.contoso)])
        var history = History(.place(.needsYou, picked: try before.picked(.line(Self.northwind.line(1)))))

        history.pick(before.step(from: history.location.picked, down: true))
        #expect(history.location.picked?.pick == .line(Self.contoso.line(0)))
        Self.keep(&history, on: after)

        #expect(Self.down(history, on: after) == .line(Self.northwind.line(0)))
    }

    /// Contoso's line picked, then Fabrikam's comes in just above it: the location the same, its standing newer.
    /// Away and Back, Contoso's answered meanwhile: ↑ goes to Fabrikam's, where the pick last stood after.
    @Test func aNewerStandingOfTheSameLocationIsTheOneBackReturnsTo() throws {
        let fabrikam = Built(id: "s3", project: "fabrikam", waiting: [22])
        let before = PlaceList(.needsYou, in: Built.listed([Self.northwind, Self.contoso]))
        let came = PlaceList(.needsYou, in: Built.listed([Self.northwind, Self.contoso, fabrikam]))
        let after = Built.listed([Self.northwind, Self.answered(Self.contoso), fabrikam])
        var history = History(.place(.needsYou, picked: try before.picked(.line(Self.contoso.line(0)))))
        let first = history.location

        history.stand(in: came)
        #expect(history.location == first)
        history.go(to: Self.kit, by: .sidebar)
        history.goBack()

        let up = PlaceList(.needsYou, in: after).step(from: history.location.picked, down: false)

        #expect(up?.pick == .line(fabrikam.line(0)))
    }

    /// Three lines held under the pointer as Northwind's session loses its window, so `watch` has its line last and
    /// the list still first; Contoso's picked there, then answered. ↓ goes to the row after it as the list shows,
    /// Fabrikam's, not as `watch` orders it.
    @Test func aPickStandsWhereTheHeldListShowsIt() throws {
        let fabrikam = Built(id: "s3", project: "fabrikam", waiting: [30])
        var away = Self.northwind
        var held = HeldLists()

        away.isAway = true
        away.waiting = [10]
        held.take(Built.listed([Built(id: "s1", project: "northwind", waiting: [10]), Self.contoso, fabrikam]))
        held.pointer(over: .list, isIn: true, at: printedAt)

        let moved = Built.listed([away, Self.contoso, fabrikam])

        held.take(moved)

        let shown = held.arranged(PlaceList(.needsYou, in: moved))
        var history = History(.place(.needsYou, picked: try shown.picked(.line(Self.contoso.line(0)))))
        let after = Built.listed([away, Self.answered(Self.contoso), fabrikam])

        held.take(after)
        history.keep(on: after) { held.arranged(PlaceList($0, in: after)) }

        let list = held.arranged(PlaceList(.needsYou, in: after))

        #expect(list.picks == [.line(away.line(0)), .line(fabrikam.line(0))])
        #expect(list.step(from: history.location.picked, down: true)?.pick == .line(fabrikam.line(0)))
        #expect(PlaceList(.needsYou, in: after).picks == [.line(fabrikam.line(0)), .line(away.line(0))])
    }
}
