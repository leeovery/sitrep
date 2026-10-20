import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// The board down the window's left, from the first line the real `watch` printed.
struct ListedTests {
    private static let listed = Listed(heard(line(0)))

    @Test func everyProjectWithSomethingOpenComesInWatchsOrderItsSessionsUnderIt() {
        #expect(Self.listed.projects.map(\.name) == ["SitRep", "Switchboard", "Goosemates"])
        #expect(Self.listed.projects.map { $0.sessions.map(\.name) } == [
            ["The Mac app"], ["Dashboard redesign", "Request ledger"], ["Settle the older open questions"],
        ])
    }

    @Test func aProjectWithNothingOpenFoldsIntoTheQuietLineAtTheFoot() {
        #expect(Self.listed.quiet.map(\.name) == ["Kit"])
    }

    @Test func aProjectsCountIsWhatWaitsOnLeeThereItsStopsAmongIt() {
        #expect(Self.listed.projects.map(\.waiting) == [3, 2, 1])
    }

    @Test func aSessionRowTakesItsMarkFromItsStateAndAnAwayOnesNameIsFaint() {
        let rows = Self.listed.sessions

        #expect(rows.map(\.mark) == [.needs, .needs, .turn, .needs])
        #expect(rows.map(\.isAway) == [false, false, false, true])
    }

    @Test func aSessionRowsTimeIsItsPanelRowsSince() throws {
        let ledger = try #require(Self.listed.sessions.first { $0.id == "sr-rq7dgr" })

        #expect(ledger.since == minutes(before: 12))
    }

    @Test func theHeadSaysWhatNeedsLeeAsThePanelsDoes() {
        #expect(Self.listed.head == Head(needYou: 6, sessions: 4))
    }

    @Test func staleTheHeadSaysWhenTheBoardWasLastKnownCurrent() {
        let stale = Listed(heard(line(0), .exited(.status(1), stderr: "")))

        #expect(stale.head.title == "6 need you")
        #expect(stale.head.count.hasPrefix("as of "))
        #expect(stale.projects.count == 3)
    }

    @Test func anAwaySessionWithNothingWaitingShowsWhereItsProjectHasSomethingOpen() throws {
        let last = heard(.line(Lines.watch[0].replacingOccurrences(of: #""key":"kit","name":"Kit","directory":"/Users/lee/Code/kit","open":0"#, with: #""key":"kit","name":"Kit","directory":"/Users/lee/Code/kit","open":1"#)))
        let kit = try #require(Listed(last).projects.first { $0.id == "kit" })

        #expect(kit.sessions.map(\.mark) == [.away])
        #expect(kit.sessions.map(\.isAway) == [true])
    }
}

struct HeldOrderTests {
    private static let first = Listed(heard(line(0)))

    /// The first board with Goosemates' session moved to the top, as a newer need would put it.
    private static let reordered: Listed = {
        var listed = first

        listed.projects = [listed.projects[2], listed.projects[0], listed.projects[1]]
        return listed
    }()

    private static func order(_ listed: Listed) -> [String] {
        listed.projects.map(\.id)
    }

    /// The order held, by reference, so an expectation can take a board.
    private final class Held {
        private var order = HeldOrder()

        var resortsAt: Date? { order.resortsAt }

        func take(_ listed: Listed, moving: Set<String>) -> Listed {
            order.take(listed, moving: moving)
        }

        func pointer(isIn: Bool, at time: Date) {
            order.pointer(isIn: isIn, at: time)
        }

        func picked(at time: Date) {
            order.picked(at: time)
        }

        func settle(at time: Date) -> Bool {
            order.settle(at: time)
        }
    }

    @Test func untouchedTheListTakesWatchsOrder() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["goosemates", "sitrep", "switchboard"])
    }

    @Test func whileThePointerIsOverTheListAChangeShowsInPlace() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["sitrep", "switchboard", "goosemates"])
    }

    /// So no row moves between two presses of an arrow key, the pointer elsewhere.
    @Test func aRunOfPicksInTheListHoldsItsOrderUntilASecondAfterTheLast() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.picked(at: printedAt)
        held.picked(at: printedAt.addingTimeInterval(0.5))
        #expect(!held.settle(at: printedAt.addingTimeInterval(1)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["sitrep", "switchboard", "goosemates"])

        let last = printedAt.addingTimeInterval(1.2)

        held.picked(at: last)
        #expect(held.resortsAt == last.addingTimeInterval(1))
        #expect(!held.settle(at: last.addingTimeInterval(0.9)))
        #expect(held.settle(at: last.addingTimeInterval(1)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["goosemates", "sitrep", "switchboard"])
    }

    @Test func aPickWithThePointerOverTheListLeavesItHeldByThePointer() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        held.picked(at: printedAt)
        #expect(held.resortsAt == nil)

        let out = printedAt.addingTimeInterval(3)

        held.pointer(isIn: false, at: out)
        #expect(held.resortsAt == out.addingTimeInterval(1))
    }

    @Test func aSessionNewToNeedingLeeMovesInAtOnceItsProjectWithIt() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        #expect(Self.order(held.take(Self.reordered, moving: ["sr-gs7kq2"])) == ["goosemates", "sitrep", "switchboard"])
    }

    @Test func aSessionMovingInTakesItsPlaceInWatchsOrderAmongItsProjectsSessions() {
        let held = Held()
        var swapped = Self.first

        swapped.projects[1].sessions.reverse()
        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        #expect(held.take(swapped, moving: []).projects[1].sessions.map(\.id) == ["sr-dash02", "sr-rq7dgr"])
        #expect(held.take(swapped, moving: ["sr-rq7dgr"]).projects[1].sessions.map(\.id) == ["sr-rq7dgr", "sr-dash02"])
    }

    @Test func whatLeavesTheBoardLeavesTheListAndWhatComesTakesItsPlaceInWatchsOrder() {
        let held = Held()
        var changed = Self.reordered

        changed.projects.remove(at: 1)
        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        #expect(Self.order(held.take(changed, moving: [])) == ["switchboard", "goosemates"])
        // SitRep comes back after Goosemates, which watch has before it
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["switchboard", "goosemates", "sitrep"])
    }

    @Test func theListReSortsASecondAfterThePointerLeavesIt() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        held.pointer(isIn: false, at: printedAt)
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["sitrep", "switchboard", "goosemates"])
        #expect(held.resortsAt == printedAt.addingTimeInterval(1))
        #expect(!held.settle(at: printedAt.addingTimeInterval(0.99)))
        #expect(held.settle(at: printedAt.addingTimeInterval(1)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["goosemates", "sitrep", "switchboard"])
    }

    @Test func thePointerBackOverTheListBeforeTheSecondIsOutKeepsItHeld() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        held.pointer(isIn: false, at: printedAt)
        held.pointer(isIn: true, at: printedAt.addingTimeInterval(0.5))
        #expect(held.resortsAt == nil)
        #expect(!held.settle(at: printedAt.addingTimeInterval(2)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["sitrep", "switchboard", "goosemates"])
    }
}
