import Foundation
@testable import SitRepWindow
import Testing

/// The middle list's rows and the sidebar's projects, held in place under the pointer and for a second after.
struct HeldListsTests {
    private static let now = Date(timeIntervalSince1970: 1_792_486_421)

    /// Three lines, one a session each, the oldest first.
    private static let one = Built(id: "s1", project: "northwind", waiting: [30])
    private static let two = Built(id: "s2", project: "contoso", waiting: [20])
    private static let three = Built(id: "s3", project: "fabrikam", waiting: [10])

    private static func away(_ session: Built) -> Built {
        var away = session

        away.isAway = true
        return away
    }

    private static func needsYou(_ held: HeldLists, _ listed: Listed) -> [ListPick] {
        held.arranged(PlaceList(.needsYou, in: listed)).picks
    }

    private static func lines(_ sessions: Built...) -> [ListPick] {
        sessions.map { .line($0.line(0)) }
    }

    /// Held under the pointer, from a board where the three lines stand in order.
    private static func heldOverThree() -> HeldLists {
        var held = HeldLists()

        held.take(Built.listed([one, two, three]), moving: [])
        held.pointer(isIn: true, at: now)
        return held
    }

    @Test func unheldTheListsTakeWatchsOrder() {
        var held = HeldLists()
        let listed = Built.listed([Self.away(Self.one), Self.two, Self.three])

        held.take(listed, moving: [])

        #expect(Self.needsYou(held, listed) == Self.lines(Self.two, Self.three, Self.one))
    }

    /// Northwind's session loses its window, so its line goes after the live ones: under the pointer it stays, and
    /// a second after the pointer leaves, it moves.
    @Test func underThePointerALineKeepsItsPlaceUntilASecondAfterItLeaves() {
        var held = Self.heldOverThree()
        let moved = Built.listed([Self.away(Self.one), Self.two, Self.three])

        held.take(moved, moving: [])
        #expect(Self.needsYou(held, moved) == Self.lines(Self.one, Self.two, Self.three))

        held.pointer(isIn: false, at: Self.now)
        #expect(held.resortsAt == Self.now.addingTimeInterval(1))
        let early = held.settle(at: Self.now.addingTimeInterval(0.5))
        let due = held.settle(at: Self.now.addingTimeInterval(1))

        #expect(!early)
        #expect(due)

        held.take(moved, moving: [])
        #expect(Self.needsYou(held, moved) == Self.lines(Self.two, Self.three, Self.one))
    }

    /// A line answered leaves the rest where they were; a line new to the list comes in where `watch` has it.
    @Test func whileHeldALineGoesAndANewOneComesInWhereWatchHasIt() {
        var held = Self.heldOverThree()
        let gone = Built.listed([Self.one, Self.three])
        let fourth = Built(id: "s4", project: "contoso", waiting: [15])
        let came = Built.listed([Self.one, Self.three, fourth])

        held.take(gone, moving: [])
        #expect(Self.needsYou(held, gone) == Self.lines(Self.one, Self.three))

        held.take(came, moving: [])
        #expect(Self.needsYou(held, came) == Self.lines(Self.one, fourth, Self.three))
    }

    /// A line new to needing Lee on the line moves in at once to where `watch` has it, held or not.
    @Test func aLineNewToNeedingLeeMovesAtOnce() {
        var held = Self.heldOverThree()
        let moved = Built.listed([Self.away(Self.one), Self.two, Self.three])

        held.take(moved, moving: [Self.one.line(0)])

        #expect(Self.needsYou(held, moved) == Self.lines(Self.two, Self.three, Self.one))
    }

    /// A pick made in the list holds it for a second after.
    @Test func aPickHoldsTheListsForASecond() {
        var held = HeldLists()
        let moved = Built.listed([Self.away(Self.one), Self.two, Self.three])

        held.take(Built.listed([Self.one, Self.two, Self.three]), moving: [])
        held.picked(at: Self.now)
        held.take(moved, moving: [])

        #expect(Self.needsYou(held, moved) == Self.lines(Self.one, Self.two, Self.three))
        #expect(held.resortsAt == Self.now.addingTimeInterval(1))
    }

    /// Each place is held on its own: a row changing place leaves its held place and takes its place in the new one.
    @Test func aRowChangingPlaceLeavesItsHeldPlace() {
        var first = Built(id: "w1", project: "northwind")
        let second = Built(id: "w2", project: "contoso")
        var held = HeldLists()

        held.take(Built.listed([first, second]), moving: [])
        held.pointer(isIn: true, at: Self.now)
        first.state = .yourTurn

        let listed = Built.listed([second, first])

        held.take(listed, moving: [])

        #expect(held.arranged(PlaceList(.working, in: listed)).picks == [.session("w2")])
        #expect(held.arranged(PlaceList(.yourTurn, in: listed)).picks == [.session("w1")])
    }

    /// The projects keep their order under the pointer as `watch` reorders them.
    @Test func theProjectsAreHeldAlike() {
        var held = Self.heldOverThree()
        let reordered = Built.listed([Self.three, Self.one, Self.two])

        held.take(reordered, moving: [])
        #expect(held.arranged(Places(reordered)).projects.map(\.id) == ["northwind", "contoso", "fabrikam"])

        held.release()
        held.take(reordered, moving: [])
        #expect(held.arranged(Places(reordered)).projects.map(\.id) == ["fabrikam", "northwind", "contoso"])
    }

    /// The fold's rows are held by their keys too.
    @Test func aFoldsRowsAreHeld() {
        var asleep = Built(id: "s1", project: "northwind")
        var held = HeldLists()

        asleep.snoozed = [(age: 30, wakesIn: 10), (age: 20, wakesIn: 20)]
        held.take(Built.listed([asleep]), moving: [])
        held.pointer(isIn: true, at: Self.now)
        asleep.snoozed = [(age: 30, wakesIn: 30), (age: 20, wakesIn: 20)]

        let listed = Built.listed([asleep])

        held.take(listed, moving: [])

        #expect(held.arranged(PlaceList(.needsYou, in: listed, isFoldOpen: true)).picks == [
            .snoozed(asleep.asleep(0)), .snoozed(asleep.asleep(1)),
        ])
    }

    /// A row the held order never took, as from a board taken after, stays, after those it holds.
    @Test func aRowTheOrderNeverTookStaysAtTheEnd() {
        var held = HeldLists()

        let listed = Built.listed([Self.one, Self.two, Self.three])

        held.take(Built.listed([Self.two, Self.three]), moving: [])

        #expect(Self.needsYou(held, listed) == Self.lines(Self.two, Self.three, Self.one))
    }
}
