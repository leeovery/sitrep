import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// What the window opens on, what it follows and when, and the boards the lines carry, over the lines the real `watch`
/// printed.
struct WindowRunTests {
    @Test func itOpensOnTheOldestSessionThatNeedsLeeAndFollowsIt() {
        let run = WindowRun(lastSession: "sr-rq7dgr")

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.following.isEmpty)
        run.open()
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.following == ["sr-macapp"])
    }

    @Test func withNothingNeedingLeeItOpensOnTheSessionPickedLast() {
        let run = WindowRun(lastSession: "sr-rq7dgr")

        run.show(heard(Self.allClear), at: printedAt, reducesMotion: false)
        run.open()
        #expect(run.following == ["sr-rq7dgr"])
    }

    @Test func withNothingNeedingLeeAndNonePickedItOpensOnTheFirstSessionListed() {
        let run = WindowRun(lastSession: "sr-zzzzzz")

        run.show(heard(Self.allClear), at: printedAt, reducesMotion: false)
        run.open()
        #expect(run.following == ["sr-macapp"])
    }

    @Test func pickingASessionMakesItTheOnePickedLast() {
        let run = opened()

        run.pick(.session("sr-rq7dgr"))
        run.close()
        run.show(heard(Self.allClear), at: printedAt, reducesMotion: false)
        run.open()
        #expect(run.pick == .session("sr-rq7dgr"))
        #expect(run.lastSession == "sr-rq7dgr")
    }

    @Test func beforeTheFirstBoardItOpensOnNothingAndPicksOnceTheBoardComes() {
        let run = WindowRun()

        run.open()
        #expect(run.following.isEmpty)
        #expect(run.page(at: printedAt) == .empty("Looking for sessions…"))
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.following == ["sr-macapp"])
    }

    @Test func aSessionPickedIsFollowedInPlaceOfTheLastAndSettingsFollowsNothing() {
        let run = opened()

        run.pick(.session("sr-dash02"))
        #expect(run.following == ["sr-dash02"])
        run.pick(.snoozed("sr-dash02"))
        #expect(run.following == ["sr-dash02"])
        run.pick(.settings)
        #expect(run.following.isEmpty)
    }

    @Test func aProjectOpenedFollowsEachOfItsSessions() {
        let run = opened()

        run.pick(.project("switchboard"))
        #expect(run.following == ["sr-dash02", "sr-rq7dgr"])
    }

    @Test func closedItFollowsNothingAndOpenedAgainItFollowsWhatItShows() {
        let run = opened()

        run.close()
        #expect(run.following.isEmpty)
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.following.isEmpty)
        run.open()
        #expect(run.following == ["sr-macapp"])
    }

    @Test func minimisedItFollowsNothingAndBackFromTheDockItFollowsItsPageAgain() {
        let run = opened()

        run.pick(.project("switchboard"))
        run.minimise()
        #expect(run.following.isEmpty)
        run.show(heard(line(0), line(1)), at: printedAt, reducesMotion: false)
        #expect(run.following.isEmpty)
        run.restore()
        #expect(run.pick == .project("switchboard"))
        #expect(run.following == ["sr-dash02", "sr-rq7dgr"])
    }

    @Test func aRunOfPicksInTheListFollowsWhatItFollowedAsItBeganUntilThePicksStopThenTheLastPick() {
        let run = opened()

        run.pickInList(.session("sr-dash02"), at: printedAt)
        #expect(run.following == ["sr-dash02"])
        run.pickInList(.session("sr-rq7dgr"), at: printedAt.addingTimeInterval(0.1))
        run.pickInList(.project("sitrep"), at: printedAt.addingTimeInterval(0.2))
        #expect(run.following == ["sr-dash02"])
        run.settle(at: printedAt.addingTimeInterval(0.3))
        #expect(run.following == ["sr-dash02"])
        run.settle(at: printedAt.addingTimeInterval(0.2 + PickFollows.settle))
        #expect(run.following == ["sr-macapp"])
    }

    @Test func aPickFromOutsideTheListEndsARunOfPicksAndIsFollowedAtOnce() {
        let run = opened()

        run.pickInList(.session("sr-dash02"), at: printedAt)
        run.pickInList(.session("sr-rq7dgr"), at: printedAt.addingTimeInterval(0.1))
        run.pick(.project("switchboard"))
        #expect(run.following == ["sr-dash02", "sr-rq7dgr"])
        #expect(run.nextChange != printedAt.addingTimeInterval(0.1 + PickFollows.settle))
    }

    /// Back from the Dock, the window follows its page at once.
    @Test func aRunOfPicksWaitingIsLetGoAsTheWindowMinimises() {
        let run = opened()

        run.pickInList(.session("sr-dash02"), at: printedAt)
        run.pickInList(.session("sr-rq7dgr"), at: printedAt.addingTimeInterval(0.1))
        run.minimise()
        run.restore()
        #expect(run.following == ["sr-rq7dgr"])
    }

    @Test func theRunOfPicksSettlingIsTheNextChange() {
        let run = opened()
        let last = printedAt.addingTimeInterval(0.1)

        run.pickInList(.session("sr-dash02"), at: printedAt)
        run.pickInList(.session("sr-rq7dgr"), at: last)
        #expect(run.nextChange == last.addingTimeInterval(PickFollows.settle))
    }

    /// So no row moves between two presses of an arrow key, the pointer elsewhere.
    @Test func aPickInTheListHoldsItsOrder() {
        let run = opened()

        run.pickInList(.session("sr-dash02"), at: printedAt)
        run.show(heard(.line(projects(["goosemates", "sitrep", "switchboard", "kit"]))), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
    }

    /// The real CLI's lines (`Lines.following`): no board on the first, then the board the follow line's look carried,
    /// beside a null for sr-n0n3zz, which no project files, said of that session alone.
    @Test func aSessionsDetailIsItsBoardFromTheLastLineThatCarriedIt() throws {
        let run = WindowRun()

        run.show(heard(.line(Lines.following[0])), at: printedAt, reducesMotion: false)
        run.open()
        #expect(run.following == ["sr-h4rn3s"])
        #expect(run.page(at: printedAt).session?.isRead == false)
        #expect(run.page(at: printedAt).session?.asks.isEmpty == true)
        run.show(heard(.line(Lines.following[1])), at: printedAt, reducesMotion: false)

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.isRead)
        #expect(page.failure == nil)
        #expect(page.asks.map(\.id.ask) == ["vx3g", "ayh1"])
        #expect(page.parked.map(\.title) == ["Measure the line on a copy of Lee's board"])
        #expect(page.notes.map(\.text).contains("The watch hears what the window follows"))
    }

    /// The real CLI's lines (`Lines.following`): the third ask posted comes on the line after, washed at the top.
    @Test func aLaterLinesBoardChangesTheDetailInPlace() throws {
        let run = WindowRun()
        let later = printedAt.addingTimeInterval(2)

        run.show(heard(.line(Lines.following[0])), at: printedAt, reducesMotion: false)
        run.open()
        run.show(heard(.line(Lines.following[1])), at: printedAt, reducesMotion: false)
        run.show(heard(.line(Lines.following[2])), at: later, reducesMotion: false)

        let asks = try #require(run.page(at: later).session?.asks)

        #expect(asks.map(\.id.ask) == ["0rzx", "vx3g", "ayh1"])
        #expect(asks.map(\.washed) == [later, nil, nil])
    }

    /// A board a line carried is said once; the line kept as `watch` goes stale says nothing again.
    @Test func aBoardKeptStaleIsNotTakenAgain() {
        let run = opened(boards: ["sr-macapp": Lines.delivered])

        run.show(
            heard(carrying(["sr-macapp": Lines.board]), .exited(.status(1), stderr: "")), at: printedAt,
            reducesMotion: false
        )
        #expect(run.page(at: printedAt).session?.asks.map(\.id.ask) == ["k2"])
    }

    @Test func aNullBoardSaysTheSessionIsNotOnTheBoardOverWhatWasShownAndKeepsIt() throws {
        let run = opened()

        take(["sr-macapp": nil], in: run)

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.failure == "This session isn't on the board.")
        #expect(page.isRead)
        #expect(page.asks.map(\.id.ask) == ["k1", "k3", "k2"])
        take(["sr-macapp": Lines.board], in: run)
        #expect(run.page(at: printedAt).session?.failure == nil)
    }

    @Test func aNullBoardFirstSaysSoWithNothingShown() throws {
        let run = opened(boards: ["sr-macapp": nil])
        let page = try #require(run.page(at: printedAt).session)

        #expect(page.failure == "This session isn't on the board.")
        #expect(!page.isRead)
        #expect(page.asks.isEmpty)
    }

    @Test func aSessionPickedAgainShowsItsAsksAsLastKeptUntilItsBoardComes() throws {
        let run = opened()

        run.pick(.session("sr-dash02"))
        run.pick(.session("sr-macapp"))
        #expect(run.page(at: printedAt).session?.asks.map(\.id.ask) == ["k1", "k3", "k2"])
        take(["sr-macapp": nil], in: run)
        #expect(run.page(at: printedAt).session?.asks.map(\.id.ask) == ["k1", "k3", "k2"])
    }

    @Test func reopenedItShowsTheSessionsAsksAsLastKeptUntilItsBoardComes() {
        let run = opened()

        run.close()
        run.open()
        #expect(run.page(at: printedAt).session?.asks.count == 3)
    }

    /// ⌘M with the pointer over the list tells no exit.
    @Test func minimisingWithThePointerOverTheListLetsTheHoldGo() {
        let run = opened()

        run.pointer(isIn: true, at: printedAt)
        run.show(heard(.line(projects(["goosemates", "sitrep", "switchboard", "kit"]))), at: printedAt, reducesMotion: false)
        run.minimise()
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["goosemates", "sitrep", "switchboard", "kit"])
        run.restore()
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
    }

    @Test func closingWithThePointerOverTheListLetsTheHoldGo() {
        let run = opened()

        run.pointer(isIn: true, at: printedAt)
        run.show(heard(.line(projects(["goosemates", "sitrep", "switchboard", "kit"]))), at: printedAt, reducesMotion: false)
        run.close()
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["goosemates", "sitrep", "switchboard", "kit"])
        run.open()
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
        #expect(run.nextChange == Self.ledgerFolds)
    }

    @Test func whatCameAndWentWhileLeeWasOnAnotherPageIsTheFirstBoardsLayoutNotWashedNorKept() throws {
        let run = opened()

        run.pick(.session("sr-dash02"))
        run.pick(.session("sr-macapp"))
        take(["sr-macapp": deliveredAndNew], in: run)

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k4", "k2"])
        #expect(page.asks.allSatisfy { $0.washed == nil && !$0.isClosed })
        #expect(page.resolved.map(\.id).contains("k1"))
        #expect(run.nextChange == Self.ledgerFolds)
    }

    @Test func whatCameAndWentWhileTheWindowWasClosedIsTheFirstBoardsLayoutNotWashedNorKept() throws {
        let run = opened()

        run.close()
        run.open()
        take(["sr-macapp": deliveredAndNew], in: run)

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k4", "k2"])
        #expect(page.asks.allSatisfy { $0.washed == nil && !$0.isClosed })
        #expect(page.resolved.map(\.id).contains("k1"))
    }

    @Test func whatComesAndGoesAfterTheFirstBoardIsWashedOrKeptInPlace() throws {
        let run = opened()

        overThePage(run)
        run.pick(.session("sr-dash02"))
        run.pick(.session("sr-macapp"))
        take(["sr-macapp": Lines.board], in: run)
        take(["sr-macapp": deliveredAndNew], in: run)

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k4", "k1", "k3", "k2"])
        #expect(page.asks.first?.washed == printedAt)
        #expect(page.asks.filter(\.isClosed).map(\.id.ask) == ["k1", "k3"])
    }

    /// Back from the Dock the page keeps its asks as they stood, so what changed meanwhile, on the board `watch`
    /// carries as the window follows the session again, is washed or kept in place.
    @Test func whatCameWhileTheWindowWasMinimisedIsWashedOrKeptInPlaceAsItShowsAgain() throws {
        let run = opened()

        overThePage(run)
        run.minimise()
        run.restore()
        overThePage(run)
        take(["sr-macapp": deliveredAndNew], in: run)

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k4", "k1", "k3", "k2"])
        #expect(page.asks.first?.washed == printedAt)
    }

    @Test func twoLinesWithoutIdsOfOneKindInOneMillisecondHaveIdsOfTheirOwnWhichStayAsLinesCome() throws {
        let run = opened()
        let twins = edited(Lines.board) { board in
            let log = board["log"] as! [[String: Any]]
            let status = log.first { $0["kind"] as? String == "status" }!

            board["log"] = [status.merging(["text": "Status: now drawing round 4"]) { $1 }, status, status] + log
        }

        take(["sr-macapp": twins], in: run)

        let before = try #require(run.page(at: printedAt).session?.notes)
        let more = edited(twins) { board in
            board["log"] = [(board["log"] as! [[String: Any]])[0].merging(["text": "Status: now drawing round 5"]) { $1 }]
                + (board["log"] as! [[String: Any]])
        }

        take(["sr-macapp": more], in: run)

        let after = try #require(run.page(at: printedAt).session?.notes)

        #expect(Set(before.map(\.id)).count == before.count)
        #expect(Array(after.dropFirst()) == before)
    }

    @Test func aNotesIdStaysAsLinesComeAndIsItsSessionsOwn() throws {
        let run = opened()
        let before = try #require(run.page(at: printedAt).session?.notes)
        var board = try JSONSerialization.jsonObject(with: Data(Lines.board.utf8)) as! [String: Any]
        let log = board["log"] as! [[String: Any]]

        board["log"] = [log[0].merging(["id": "n3", "text": "Round 4 drawn"]) { $1 }] + log
        take(["sr-macapp": String(decoding: try JSONSerialization.data(withJSONObject: board), as: UTF8.self)], in: run)

        let after = try #require(run.page(at: printedAt).session?.notes)

        #expect(after.map(\.text).first == "Round 4 drawn")
        #expect(Array(after.dropFirst()) == before)
        #expect(Set(after.map(\.id)).count == after.count)
        #expect(after.allSatisfy { $0.id.hasPrefix("sr-macapp:") })
    }

    @Test func aPickGoneFromTheBoardGivesWayToWhatTheWindowOpensOn() {
        let run = opened()

        run.pick(.session("sr-gs7kq2"))
        run.show(heard(line(0), line(3)), at: printedAt, reducesMotion: false)
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.following == ["sr-macapp"])
    }

    @Test func aSessionNewToNeedingLeeIsWashedForTwoSeconds() {
        let run = opened()

        run.show(heard(line(0), line(new: ["ask:sr-gs7kq2:k1"])), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt.addingTimeInterval(1.99)).rows.compactMap(\.washed) == [printedAt])
        #expect(run.listed(at: printedAt.addingTimeInterval(1.99)).needsYou.compactMap(\.washed) == [printedAt])
        #expect(run.listed(at: printedAt.addingTimeInterval(2)).rows.compactMap(\.washed).isEmpty)
        #expect(run.listed(at: printedAt.addingTimeInterval(2)).needsYou.compactMap(\.washed).isEmpty)
    }

    /// A new ask on a row of several lines: the row washes, and of its lines only the new one, which its age says.
    @Test func ofARowsLinesOnlyTheNewOneIsWashed() throws {
        let run = opened()

        run.show(heard(line(0), line(new: ["ask:sr-macapp:k3"])), at: printedAt, reducesMotion: false)

        let row = try #require(run.listed(at: printedAt.addingTimeInterval(1)).needsYou.first { $0.id == "sr-macapp" })
        #expect(row.washed == printedAt)
        #expect(row.lines.map(\.washed) == [nil, printedAt, nil])
        #expect(run.listed(at: printedAt.addingTimeInterval(2)).needsYou.flatMap(\.lines).allSatisfy { $0.washed == nil })
    }

    @Test func underReducedMotionNothingIsWashed() {
        let run = opened()

        run.show(heard(line(0), line(new: ["ask:sr-gs7kq2:k1"])), at: printedAt, reducesMotion: true)
        #expect(run.listed(at: printedAt).rows.compactMap(\.washed).isEmpty)
        #expect(run.listed(at: printedAt).needsYou.flatMap(\.lines).allSatisfy { $0.washed == nil })
    }

    @Test func staleNothingOnTheBoardIsNewAgain() {
        let run = opened()
        let stale = heard(line(0), line(new: ["ask:sr-gs7kq2:k1"]), .exited(.status(1), stderr: ""))

        run.show(stale, at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).rows.compactMap(\.washed).isEmpty)
        #expect(run.listed(at: printedAt).head.count.hasPrefix("as of "))
    }

    @Test func aWashEndingIsTheNextChange() {
        let run = opened()

        run.show(heard(line(0), line(new: ["ask:sr-gs7kq2:k1"])), at: printedAt, reducesMotion: false)
        #expect(run.nextChange == printedAt.addingTimeInterval(2))
    }

    @Test func theListTakesWatchsOrderASecondAfterThePointerLeavesIt() {
        let run = opened()

        run.pointer(isIn: true, at: printedAt)
        run.show(heard(.line(projects(["goosemates", "sitrep", "switchboard", "kit"]))), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
        run.pointer(isIn: false, at: printedAt)
        #expect(run.nextChange == printedAt.addingTimeInterval(1))
        run.settle(at: printedAt.addingTimeInterval(0.5))
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
        run.settle(at: printedAt.addingTimeInterval(1))
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["goosemates", "sitrep", "switchboard", "kit"])
        #expect(run.nextChange == Self.ledgerFolds)
    }

    @Test func withNoWatchToRunTheHeadAndThePageSayWhy() {
        let run = WindowRun()

        run.unrun("This SitRep names no plugin to run: build it with app/build.")
        #expect(run.listed(at: printedAt).head.title == "This SitRep names no plugin to run: build it with app/build.")
        #expect(run.page(at: printedAt) == .empty("This SitRep names no plugin to run: build it with app/build."))
    }

    @Test func withNoSessionOpenAtAllThePageSaysSo() {
        let run = WindowRun()
        let empty = #"{"v":3,"at":1792486421238,"version":"0.2.0","head":{"needYou":0,"sessions":0},"rows":[],"projects":[],"windows":[],"new":[],"boards":{}}"#

        run.show(heard(.line(empty)), at: printedAt, reducesMotion: false)
        run.open()
        #expect(run.page(at: printedAt) == .empty("No session is open."))
    }

    /// When Request ledger's turn, ended 12 minutes before the first board, passes the hour and folds into "N earlier":
    /// the one change by time alone that board holds.
    private static let ledgerFolds = minutes(before: 12).addingTimeInterval(3600)

    /// The first board with no ask waiting and no window stopped: nothing needs Lee.
    private static let allClear = Heard.line(
        Lines.watch[0]
            .replacingOccurrences(of: #""is":"ask""#, with: #""is":"yourTurn""#)
            .replacingOccurrences(of: #""is":"permission""#, with: #""is":"yourTurn""#)
            .replacingOccurrences(of: #""section":"needsYou""#, with: #""section":"yourTurn""#)
    )
}
