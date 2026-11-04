import Foundation
@testable import SitRepWindow
import Testing

/// The middle list's rows and the sidebar's projects, each held in place under the pointer and for a second after.
struct HeldListsTests {
    private static let now = Date(timeIntervalSince1970: 1_792_486_421)

    /// Three lines, one a session each, the newest first.
    private static let one = Built(id: "s1", project: "northwind", waiting: [10])
    private static let two = Built(id: "s2", project: "contoso", waiting: [20])
    private static let three = Built(id: "s3", project: "fabrikam", waiting: [30])
    /// The three, Northwind's session's window gone, so its line goes after the live ones, and its project after
    /// theirs.
    private static let moved = Built.listed([three, two, away(one)])

    private static func away(_ session: Built) -> Built {
        var away = session

        away.isAway = true
        return away
    }

    private static func needsYou(_ held: HeldLists, _ listed: Listed, filter: Filter = Filter()) -> [ListPick] {
        held.arranged(PlaceList(.needsYou, in: listed, filter: filter)).picks
    }

    private static func projects(_ held: HeldLists, _ listed: Listed) -> [String] {
        held.arranged(Places(listed)).projects.map(\.id)
    }

    private static func lines(_ sessions: Built...) -> [ListPick] {
        sessions.map { .line($0.line(0)) }
    }

    /// Taken from a board where the three lines stand in order, the pointer over the column given.
    private static func held(over column: HeldLists.Column) -> HeldLists {
        var held = HeldLists()

        held.take(Built.listed([one, two, three]))
        held.pointer(over: column, isIn: true, at: now)
        return held
    }

    @Test func unheldTheListsTakeWatchsOrder() {
        var held = HeldLists()

        held.take(Self.moved)

        #expect(Self.needsYou(held, Self.moved) == Self.lines(Self.two, Self.three, Self.one))
        #expect(Self.projects(held, Self.moved) == ["fabrikam", "contoso", "northwind"])
    }

    /// Under the pointer the line stays, and a second after the pointer leaves, it moves.
    @Test func underThePointerALineKeepsItsPlaceUntilASecondAfterItLeaves() {
        var held = Self.held(over: .list)

        held.take(Self.moved)
        #expect(Self.needsYou(held, Self.moved) == Self.lines(Self.one, Self.two, Self.three))

        held.pointer(over: .list, isIn: false, at: Self.now)

        let early = held.settle(at: Self.now.addingTimeInterval(0.5))
        let due = held.settle(at: Self.now.addingTimeInterval(1))

        #expect(!early)
        #expect(due)

        held.take(Self.moved)
        #expect(Self.needsYou(held, Self.moved) == Self.lines(Self.two, Self.three, Self.one))
    }

    /// A line answered leaves the rest where they were; a line new on the board has a key new to the list, so it
    /// comes in at once where `watch` has it, held or not.
    @Test func whileHeldALineGoesAndANewOneComesInWhereWatchHasIt() {
        var held = Self.held(over: .list)
        let gone = Built.listed([Self.one, Self.three])
        let fourth = Built(id: "s4", project: "contoso", waiting: [15])
        let came = Built.listed([Self.one, Self.three, fourth])

        held.take(gone)
        #expect(Self.needsYou(held, gone) == Self.lines(Self.one, Self.three))

        held.take(came)
        #expect(Self.needsYou(held, came) == Self.lines(Self.one, fourth, Self.three))
    }

    /// A snoozed ask woken while the list is held: its key comes back as a line, new to the list, so it comes in
    /// where `watch` has it, and its row in the fold goes.
    @Test func aSnoozedAskWokenWhileHeldComesInAsALine() {
        var asleep = Self.two
        var held = HeldLists()

        asleep.waiting = []
        asleep.snoozed = [(age: 20, wakesIn: 5)]
        held.take(Built.listed([Self.one, asleep, Self.three]))
        held.pointer(over: .list, isIn: true, at: Self.now)
        held.take(Built.listed([Self.one, Self.two, Self.three]))

        let woken = held.arranged(PlaceList(.needsYou, in: Built.listed([Self.one, Self.two, Self.three]), isFoldOpen: true))

        #expect(woken.picks == [.line(Self.one.line(0)), .line("ask:s2:k0"), .line(Self.three.line(0))])
        #expect(woken.fold == nil)
    }

    /// A pick made in the list holds it for a second after.
    @Test func aPickHoldsTheListForASecond() {
        var held = HeldLists()

        held.take(Built.listed([Self.one, Self.two, Self.three]))
        held.picked(in: .list, at: Self.now)
        held.take(Self.moved)

        #expect(Self.needsYou(held, Self.moved) == Self.lines(Self.one, Self.two, Self.three))
        #expect(Self.projects(held, Self.moved) == ["fabrikam", "contoso", "northwind"])
        #expect(held.resortsAt == Self.now.addingTimeInterval(1))
    }

    /// The pointer over the projects holds them, and leaves the list free to take `watch`'s order.
    @Test func thePointerOverTheProjectsHoldsThemAndNotTheList() {
        var held = Self.held(over: .projects)

        held.take(Self.moved)

        #expect(Self.projects(held, Self.moved) == ["northwind", "contoso", "fabrikam"])
        #expect(Self.needsYou(held, Self.moved) == Self.lines(Self.two, Self.three, Self.one))
    }

    /// From the list to the projects, the column come to coming before the one left or after: each holds as the
    /// pointer over it says, the list for its second after.
    @Test func crossingFromOneColumnToTheOtherHoldsEachAsThePointerSays() {
        for comesFirst in [true, false] {
            var held = Self.held(over: .list)
            let crossings: [(HeldLists.Column, Bool)] = comesFirst
                ? [(.projects, true), (.list, false)]
                : [(.list, false), (.projects, true)]

            crossings.forEach { held.pointer(over: $0.0, isIn: $0.1, at: Self.now) }
            held.take(Self.moved)
            #expect(Self.needsYou(held, Self.moved) == Self.lines(Self.one, Self.two, Self.three))
            #expect(Self.projects(held, Self.moved) == ["northwind", "contoso", "fabrikam"])

            _ = held.settle(at: Self.now.addingTimeInterval(1))
            held.take(Self.moved)
            #expect(Self.needsYou(held, Self.moved) == Self.lines(Self.two, Self.three, Self.one))
            #expect(Self.projects(held, Self.moved) == ["northwind", "contoso", "fabrikam"])
        }
    }

    /// Each place is held on its own: a row changing place leaves its held place and takes its place in the new one.
    @Test func aRowChangingPlaceLeavesItsHeldPlace() {
        var first = Built(id: "w1", project: "northwind")
        let second = Built(id: "w2", project: "contoso")
        var held = HeldLists()

        held.take(Built.listed([first, second]))
        held.pointer(over: .list, isIn: true, at: Self.now)
        first.state = .yourTurn

        let listed = Built.listed([second, first])

        held.take(listed)

        #expect(held.arranged(PlaceList(.working, in: listed)).picks == [.session("w2")])
        #expect(held.arranged(PlaceList(.yourTurn, in: listed)).picks == [.session("w1")])
    }

    /// The projects keep their order under the pointer as `watch` reorders them.
    @Test func theProjectsAreHeldAlike() {
        var held = Self.held(over: .projects)
        let reordered = Built.listed([Self.three, Self.one, Self.two])

        held.take(reordered)
        #expect(Self.projects(held, reordered) == ["northwind", "contoso", "fabrikam"])

        held.release()
        held.take(reordered)
        #expect(Self.projects(held, reordered) == ["fabrikam", "northwind", "contoso"])
    }

    /// The fold's rows are held by their keys too.
    @Test func aFoldsRowsAreHeld() {
        var asleep = Built(id: "s1", project: "northwind")
        var held = HeldLists()

        asleep.snoozed = [(age: 30, wakesIn: 10), (age: 20, wakesIn: 20)]
        held.take(Built.listed([asleep]))
        held.pointer(over: .list, isIn: true, at: Self.now)
        asleep.snoozed = [(age: 30, wakesIn: 30), (age: 20, wakesIn: 20)]

        let listed = Built.listed([asleep])

        held.take(listed)

        #expect(held.arranged(PlaceList(.needsYou, in: listed, isFoldOpen: true)).picks == [
            .snoozed(asleep.asleep(0)), .snoozed(asleep.asleep(1)),
        ])
    }

    /// A list narrowed by the filter keeps the order held of what it keeps.
    @Test func aFilteredListKeepsTheOrderHeld() {
        var held = Self.held(over: .list)

        held.take(Self.moved)

        #expect(Self.needsYou(held, Self.moved, filter: Filter("Session s")) == Self.lines(Self.one, Self.two, Self.three))
        #expect(Self.needsYou(held, Self.moved, filter: Filter("northwind")) == Self.lines(Self.one))
    }

    /// A row the held order never took, as from a board taken after, stays, after those it holds.
    @Test func aRowTheOrderNeverTookStaysAtTheEnd() {
        var held = HeldLists()
        let listed = Built.listed([Self.one, Self.two, Self.three])

        held.take(Built.listed([Self.two, Self.three]))

        #expect(Self.needsYou(held, listed) == Self.lines(Self.two, Self.three, Self.one))
    }
}
