import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// The board down the window's left, from what the real `watch` printed: a row for each of core's, in its section,
/// each session once; and every project.
struct ListedTests {
    private static let listed = Listed(heard(line(0)))
    /// Harness's three asks, Switchboard's ask and prompt and Goosemates' away ask; SitRep working, Kit on its own work;
    /// Fumi's turn.
    private static let bySession = Listed(heard(.line(Lines.bySession[0])))

    /// Each section in the sections' order, Your turn above Working, each section's rows in core's order.
    @Test func eachSessionHasOneRowInItsSectionInCoresOrder() {
        #expect(Self.bySession.rows.map(\.id) == [
            "sr-4g01a7", "sr-dash02", "sr-gs7kq2", "sr-v3t7a0", "sr-macapp", "sr-k7bt2s",
        ])
        #expect(Self.bySession.rows.map(\.section) == [.needsYou, .needsYou, .needsYou, .yourTurn, .working, .working])
        #expect(Self.bySession.needsYou.map(\.id) == ["sr-4g01a7", "sr-dash02", "sr-gs7kq2"])
    }

    /// Goosemates' ask, which no window holds, takes the away ring.
    @Test func aRowTakesItsMarkFromItsLineAndNamesItsProject() {
        #expect(Self.bySession.rows.map(\.mark) == [.needs, .needs, .awayAsk, .turn, .working, .onItsWork])
        #expect(Self.bySession.rows.map(\.isAway) == [false, false, true, false, false, false])
        #expect(Self.bySession.rows.map(\.project) == ["Harness", "Switchboard", "Goosemates", "Fumi", "SitRep", "Kit"])
    }

    /// A working row's verb and what it acts on, a your-turn row's words, each its one line.
    @Test func aRowsLinesAreCoresWithTheirWords() {
        let rows = Self.bySession.rows

        #expect(rows.map(\.lines.count) == [3, 2, 1, 1, 1, 1])
        #expect(rows[4].lines.map(\.words) == ["Grouping the rows by session"])
        #expect(rows[5].lines.map(\.words) == ["Waiting on 3 agents"])
        #expect(rows[3].lines.map(\.words) == ["Comparing licence servers"])
        #expect(rows[1].lines.map(\.words) == ["Paste the load test's output", "Allow Bash gh pr create --draft"])
    }

    /// Kit's window waits on a wake 12 minutes off: its line counts down to it.
    @Test func aWakesLineCountsDownToIt() throws {
        let listed = Listed(heard(.line(Lines.onItsWork)))
        let kit = try #require(listed.rows.first { $0.id == "sr-k7bt2s" }?.lines.first)
        let board = try Board.read(Lines.onItsWork)

        #expect(kit.lead == "Wakes")
        #expect(kit.subject(at: board.at) == "in 12m")
    }

    @Test func everyProjectOnTheBoardIsListedQuietOnesTooInWatchsOrder() {
        #expect(Self.listed.projects.map(\.name) == ["SitRep", "Switchboard", "Goosemates", "Kit"])
        #expect(Self.listed.projects.map(\.pick) == [
            .project("sitrep"), .project("switchboard"), .project("goosemates"), .project("kit"),
        ])
    }

    /// Kit's away session waits on nothing, so core has no row for it: it is reached by its project's page.
    @Test func anAwaySessionWithNothingWaitingHasNoRow() {
        #expect(!Self.listed.rows.contains { $0.id == "sr-k7t001" })
        #expect(Self.listed.rowless == ["sr-k7t001": "kit"])
        #expect(Self.bySession.rowless.isEmpty)
    }

    /// A session with no row of its own shows at its project's row; with its project not listed either, nowhere.
    @Test func aSessionWithNoRowShowsAtItsProjectsRow() {
        var unlisted = Self.listed

        unlisted.projects.removeAll { $0.id == "kit" }

        #expect(Self.listed.listedRow(showing: .session("sr-k7t001")) == .project("kit"))
        #expect(Self.listed.listedRow(showing: .session("sr-rq7dgr")) == .session("sr-rq7dgr"))
        #expect(Self.listed.listedRow(showing: .project("kit")) == .project("kit"))
        #expect(Self.listed.listedRow(showing: .session("sr-gone")) == nil)
        #expect(unlisted.listedRow(showing: .session("sr-k7t001")) == nil)
    }

    @Test func aRowsTimeIsItsOldestLines() throws {
        let ledger = try #require(Self.listed.rows.first { $0.id == "sr-rq7dgr" })

        #expect(ledger.since == minutes(before: 12))
    }

    @Test func theHeadSaysWhatNeedsLeeAsThePanelsDoes() {
        #expect(Self.listed.head == Head(needYou: 6, sessions: 4))
    }

    @Test func staleTheHeadSaysWhenTheBoardWasLastKnownCurrent() {
        let stale = Listed(heard(line(0), .exited(.status(1), stderr: "")))

        #expect(stale.head.title == "6 need you")
        #expect(stale.head.count.hasPrefix("as of "))
        #expect(stale.projects.count == 4)
    }
}

struct HeldOrderTests {
    private static let first = Listed(heard(line(0)))

    /// The first board with Goosemates' ask moved to the top of Needs you and its project to the top of Projects, as
    /// a newer need would put them.
    private static let reordered: Listed = {
        var listed = first

        listed.rows = [listed.rows[2], listed.rows[0], listed.rows[1], listed.rows[3]]
        listed.projects = [listed.projects[2], listed.projects[0], listed.projects[1], listed.projects[3]]
        return listed
    }()

    private static let firstOrder = ["sr-macapp", "sr-dash02", "sr-gs7kq2", "sr-rq7dgr"]
    private static let newOrder = ["sr-gs7kq2", "sr-macapp", "sr-dash02", "sr-rq7dgr"]

    private static func order(_ listed: Listed) -> [String] {
        listed.rows.map(\.id)
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
        #expect(Self.order(held.take(Self.reordered, moving: [])) == Self.newOrder)
    }

    @Test func whileThePointerIsOverTheListAChangeShowsInPlaceProjectsTooInPlace() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)

        let taken = held.take(Self.reordered, moving: [])

        #expect(Self.order(taken) == Self.firstOrder)
        #expect(taken.projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
    }

    /// So no row moves between two presses of an arrow key, the pointer elsewhere.
    @Test func aRunOfPicksInTheListHoldsItsOrderUntilASecondAfterTheLast() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.picked(at: printedAt)
        held.picked(at: printedAt.addingTimeInterval(0.5))
        #expect(!held.settle(at: printedAt.addingTimeInterval(1)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == Self.firstOrder)

        let last = printedAt.addingTimeInterval(1.2)

        held.picked(at: last)
        #expect(held.resortsAt == last.addingTimeInterval(1))
        #expect(!held.settle(at: last.addingTimeInterval(0.9)))
        #expect(held.settle(at: last.addingTimeInterval(1)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == Self.newOrder)
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

    @Test func aSessionNewToNeedingLeeMovesInAtOnceToWhereWatchHasIt() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        #expect(Self.order(held.take(Self.reordered, moving: ["sr-gs7kq2"])) == Self.newOrder)
    }

    /// Request ledger's turn ends in a new ask: it leaves Your turn and takes its place in Needs you, where `watch`
    /// has it, though the list is held; its row is the same session's.
    @Test func aRowChangingSectionTakesItsPlaceInItsNewSectionWhileHeld() {
        let held = Held()
        let asking = Listed(heard(line(0), asked("sr-rq7dgr")))

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)

        let taken = held.take(asking, moving: [])

        #expect(taken.needsYou.map(\.id) == asking.needsYou.map(\.id))
        #expect(taken.rows(in: .yourTurn).isEmpty)
    }

    @Test func whatLeavesTheBoardLeavesTheListAndWhatComesTakesItsPlaceInWatchsOrder() {
        let held = Held()
        var changed = Self.reordered

        changed.rows.remove(at: 1)
        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        #expect(Self.order(held.take(changed, moving: [])) == ["sr-dash02", "sr-gs7kq2", "sr-rq7dgr"])
        // the Mac app comes back after Goosemates' ask, which watch has before it
        #expect(Self.order(held.take(Self.reordered, moving: [])) == ["sr-dash02", "sr-gs7kq2", "sr-macapp", "sr-rq7dgr"])
    }

    @Test func theListReSortsASecondAfterThePointerLeavesIt() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        held.pointer(isIn: false, at: printedAt)
        #expect(Self.order(held.take(Self.reordered, moving: [])) == Self.firstOrder)
        #expect(held.resortsAt == printedAt.addingTimeInterval(1))
        #expect(!held.settle(at: printedAt.addingTimeInterval(0.99)))
        #expect(held.settle(at: printedAt.addingTimeInterval(1)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == Self.newOrder)
    }

    @Test func thePointerBackOverTheListBeforeTheSecondIsOutKeepsItHeld() {
        let held = Held()

        _ = held.take(Self.first, moving: [])
        held.pointer(isIn: true, at: printedAt)
        held.pointer(isIn: false, at: printedAt)
        held.pointer(isIn: true, at: printedAt.addingTimeInterval(0.5))
        #expect(held.resortsAt == nil)
        #expect(!held.settle(at: printedAt.addingTimeInterval(2)))
        #expect(Self.order(held.take(Self.reordered, moving: [])) == Self.firstOrder)
    }
}
