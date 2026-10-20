import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// What the window opens on, what it reads and when, over the lines the real `watch` printed.
struct WindowRunTests {
    @Test func itOpensOnTheOldestSessionThatNeedsLeeAndReadsItsBoard() {
        let run = WindowRun(lastSession: "sr-rq7dgr")

        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.open().map(\.session) == ["sr-macapp"])
        #expect(run.pick == .session("sr-macapp"))
    }

    @Test func withNothingNeedingLeeItOpensOnTheSessionPickedLast() {
        let run = WindowRun(lastSession: "sr-rq7dgr")

        _ = run.show(heard(Self.allClear), at: printedAt, reducesMotion: false)
        #expect(run.open().map(\.session) == ["sr-rq7dgr"])
    }

    @Test func withNothingNeedingLeeAndNonePickedItOpensOnTheFirstSessionListed() {
        let run = WindowRun(lastSession: "sr-zzzzzz")

        _ = run.show(heard(Self.allClear), at: printedAt, reducesMotion: false)
        #expect(run.open().map(\.session) == ["sr-macapp"])
    }

    @Test func pickingASessionMakesItTheOnePickedLast() {
        let run = opened()

        _ = run.pick(.session("sr-rq7dgr"))
        run.close()
        _ = run.show(heard(Self.allClear), at: printedAt, reducesMotion: false)
        _ = run.open()
        #expect(run.pick == .session("sr-rq7dgr"))
        #expect(run.lastSession == "sr-rq7dgr")
    }

    @Test func beforeTheFirstBoardItOpensOnNothingAndPicksOnceTheBoardComes() {
        let run = WindowRun()

        #expect(run.open().isEmpty)
        #expect(run.page(at: printedAt) == .empty("Looking for sessions…"))
        #expect(run.show(heard(line(0)), at: printedAt, reducesMotion: false).map(\.session) == ["sr-macapp"])
    }

    @Test func closedItReadsNothing() {
        let run = opened()

        run.close()
        #expect(run.show(heard(line(0), line(1)), at: printedAt, reducesMotion: false).isEmpty)
    }

    @Test func aSessionShownIsReadAgainWhenWatchSaysItsBoardChanged() {
        let run = opened()

        #expect(run.show(heard(line(0), line(changed: ["sr-macapp"])), at: printedAt, reducesMotion: false).map(\.session) == ["sr-macapp"])
        #expect(run.show(heard(line(0), line(changed: ["sr-dash02"])), at: printedAt, reducesMotion: false).isEmpty)
    }

    @Test func onABoardResumedAfterWatchWasDownEverySessionShownIsReadAgain() {
        let run = opened()

        _ = run.pick(.project("switchboard"))
        #expect(run.show(heard(line(0), runs: 2), at: printedAt, reducesMotion: false).map(\.session) == ["sr-dash02", "sr-rq7dgr"])
    }

    @Test func aProjectsViewReadsEachOfItsSessions() {
        let run = opened()

        #expect(run.pick(.project("switchboard")).map(\.session) == ["sr-dash02", "sr-rq7dgr"])
    }

    @Test func onlyTheLatestReadAskedForASessionIsTaken() throws {
        let run = WindowRun()

        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)

        let earlier = try #require(run.open().first)
        let later = try #require(run.pick(.session("sr-macapp")).first)

        run.read(later, gave: board(Lines.delivered), at: printedAt, reducesMotion: false)
        run.read(earlier, gave: board(Lines.board), at: printedAt, reducesMotion: false)
        #expect(run.page(at: printedAt).session?.asks.map(\.id.ask) == ["k2"])
    }

    @Test func aReadThatFailsSaysWhyUntilOneReadsAndKeepsWhatWasReadBefore() throws {
        let run = WindowRun()

        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)

        let first = try #require(run.open().first)

        run.read(first, gave: .failed("sitrep board did not answer within 10 seconds."), at: printedAt, reducesMotion: false)
        #expect(run.page(at: printedAt).session?.failure == "sitrep board did not answer within 10 seconds.")
        #expect(run.page(at: printedAt).session?.isRead == false)

        let second = try #require(run.pick(.session("sr-macapp")).first)

        run.read(second, gave: board(Lines.board), at: printedAt, reducesMotion: false)
        #expect(run.page(at: printedAt).session?.failure == nil)
        #expect(run.page(at: printedAt).session?.isRead == true)

        let third = try #require(run.pick(.session("sr-macapp")).first)

        run.read(third, gave: .failed("sitrep board ended with status 1."), at: printedAt, reducesMotion: false)
        #expect(run.page(at: printedAt).session?.asks.count == 3)
        #expect(run.page(at: printedAt).session?.failure == "sitrep board ended with status 1.")
    }

    @Test func aSessionPickedAgainShowsItsAsksAsLastReadUntilItsReadLandsAndKeepsThemIfItFails() throws {
        let run = opened()

        _ = run.pick(.session("sr-dash02"))

        let again = try #require(run.pick(.session("sr-macapp")).first)

        #expect(run.page(at: printedAt).session?.asks.map(\.id.ask) == ["k1", "k3", "k2"])
        run.read(again, gave: .failed("sitrep board ended with status 1."), at: printedAt, reducesMotion: false)
        #expect(run.page(at: printedAt).session?.asks.map(\.id.ask) == ["k1", "k3", "k2"])
        #expect(run.page(at: printedAt).session?.failure == "sitrep board ended with status 1.")
    }

    @Test func reopenedItShowsTheSessionsAsksAsLastReadUntilItsReadLands() {
        let run = opened()

        run.close()
        _ = run.open()
        #expect(run.page(at: printedAt).session?.asks.count == 3)
    }

    @Test func closingWithThePointerOverTheListLetsTheHoldGo() {
        let run = opened()

        run.pointer(isIn: true, at: printedAt)
        _ = run.show(heard(.line(projects(["goosemates", "sitrep", "switchboard", "kit"]))), at: printedAt, reducesMotion: false)
        run.close()
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["goosemates", "sitrep", "switchboard"])
        _ = run.open()
        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates"])
        #expect(run.nextChange == nil)
    }

    @Test func whatCameAndWentWhileLeeWasOnAnotherPageIsTheFirstReadsLayoutNotWashedNorKept() throws {
        let run = opened()

        _ = run.pick(.session("sr-dash02"))
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": deliveredAndNew])

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k4", "k2"])
        #expect(page.asks.allSatisfy { $0.washed == nil && !$0.isClosed })
        #expect(page.resolved.map(\.id).contains("k1"))
        #expect(run.nextChange == nil)
    }

    @Test func whatCameAndWentWhileTheWindowWasClosedIsTheFirstReadsLayoutNotWashedNorKept() throws {
        let run = opened()

        run.close()
        answer(run.open(), in: run, with: ["sr-macapp": deliveredAndNew])

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k4", "k2"])
        #expect(page.asks.allSatisfy { $0.washed == nil && !$0.isClosed })
        #expect(page.resolved.map(\.id).contains("k1"))
    }

    @Test func whatComesAndGoesAfterTheFirstReadIsWashedOrKeptInPlace() throws {
        let run = opened()

        _ = run.pick(.session("sr-dash02"))
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.board])
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": deliveredAndNew])

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k4", "k1", "k3", "k2"])
        #expect(page.asks.first?.washed == printedAt)
        #expect(page.asks.filter(\.isClosed).map(\.id.ask) == ["k1", "k3"])
    }

    @Test func minimisedNothingIsReadBroughtBackThePageReadsWhatItShowsAgain() {
        let run = opened()

        run.minimise()
        #expect(run.show(heard(line(0), line(1)), at: printedAt, reducesMotion: false).isEmpty)
        #expect(run.show(heard(line(0), runs: 2), at: printedAt, reducesMotion: false).isEmpty)
        #expect(run.restore().map(\.session) == ["sr-macapp"])
        #expect(run.pick == .session("sr-macapp"))
    }

    @Test func twoLinesWithoutIdsOfOneKindInOneMillisecondHaveIdsOfTheirOwnWhichStayAsLinesCome() throws {
        let run = opened()
        let twins = edited(Lines.board) { board in
            let log = board["log"] as! [[String: Any]]
            let status = log.first { $0["kind"] as? String == "status" }!

            board["log"] = [status.merging(["text": "Status: now drawing round 4"]) { $1 }, status, status] + log
        }

        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": twins])

        let before = try #require(run.page(at: printedAt).session?.notes)
        let more = edited(twins) { board in
            board["log"] = [(board["log"] as! [[String: Any]])[0].merging(["text": "Status: now drawing round 5"]) { $1 }]
                + (board["log"] as! [[String: Any]])
        }

        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": more])

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
        answer(
            run.pick(.session("sr-macapp")), in: run,
            with: ["sr-macapp": String(decoding: try JSONSerialization.data(withJSONObject: board), as: UTF8.self)]
        )

        let after = try #require(run.page(at: printedAt).session?.notes)

        #expect(after.map(\.text).first == "Round 4 drawn")
        #expect(Array(after.dropFirst()) == before)
        #expect(Set(after.map(\.id)).count == after.count)
        #expect(after.allSatisfy { $0.id.hasPrefix("sr-macapp:") })
    }

    @Test func aPickGoneFromTheBoardGivesWayToWhatTheWindowOpensOn() {
        let run = opened()

        _ = run.pick(.session("sr-gs7kq2"))
        #expect(run.show(heard(line(0), line(3)), at: printedAt, reducesMotion: false).map(\.session) == ["sr-macapp"])
        #expect(run.pick == .session("sr-macapp"))
    }

    @Test func aSessionNewToNeedingLeeIsWashedForTwoSeconds() {
        let run = opened()

        _ = run.show(heard(line(0), line(new: ["ask:sr-gs7kq2:k1"])), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt.addingTimeInterval(1.99)).sessions.compactMap(\.washed) == [printedAt])
        #expect(run.listed(at: printedAt.addingTimeInterval(2)).sessions.compactMap(\.washed).isEmpty)
    }

    @Test func underReducedMotionNothingIsWashed() {
        let run = opened()

        _ = run.show(heard(line(0), line(new: ["ask:sr-gs7kq2:k1"])), at: printedAt, reducesMotion: true)
        #expect(run.listed(at: printedAt).sessions.compactMap(\.washed).isEmpty)
    }

    @Test func staleNothingOnTheBoardIsNewAgain() {
        let run = opened()
        let stale = heard(line(0), line(new: ["ask:sr-gs7kq2:k1"]), .exited(.status(1), stderr: ""))

        _ = run.show(stale, at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).sessions.compactMap(\.washed).isEmpty)
        #expect(run.listed(at: printedAt).head.count.hasPrefix("as of "))
    }

    @Test func aWashEndingIsTheNextChange() {
        let run = opened()

        _ = run.show(heard(line(0), line(new: ["ask:sr-gs7kq2:k1"])), at: printedAt, reducesMotion: false)
        #expect(run.nextChange == printedAt.addingTimeInterval(2))
    }

    @Test func theListTakesWatchsOrderASecondAfterThePointerLeavesIt() {
        let run = opened()

        run.pointer(isIn: true, at: printedAt)
        _ = run.show(heard(.line(projects(["goosemates", "sitrep", "switchboard", "kit"]))), at: printedAt, reducesMotion: false)
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates"])
        run.pointer(isIn: false, at: printedAt)
        #expect(run.nextChange == printedAt.addingTimeInterval(1))
        run.settle(at: printedAt.addingTimeInterval(0.5))
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["sitrep", "switchboard", "goosemates"])
        run.settle(at: printedAt.addingTimeInterval(1))
        #expect(run.listed(at: printedAt).projects.map(\.id) == ["goosemates", "sitrep", "switchboard"])
        #expect(run.nextChange == nil)
    }

    @Test func withNoWatchToRunTheHeadAndThePageSayWhy() {
        let run = WindowRun()

        run.unrun("This SitRep names no plugin to run: build it with app/build.")
        #expect(run.listed(at: printedAt).head.title == "This SitRep names no plugin to run: build it with app/build.")
        #expect(run.page(at: printedAt) == .empty("This SitRep names no plugin to run: build it with app/build."))
    }

    @Test func withNoSessionOpenAtAllThePageSaysSo() {
        let run = WindowRun()
        let empty = #"{"v":1,"at":1792486421238,"version":"0.2.0","head":{"needYou":0,"sessions":0},"rows":[],"projects":[],"windows":[],"new":[],"changed":[]}"#

        _ = run.show(heard(.line(empty)), at: printedAt, reducesMotion: false)
        _ = run.open()
        #expect(run.page(at: printedAt) == .empty("No session is open."))
    }

    /// The first board with no ask waiting and no window stopped: nothing needs Lee.
    private static let allClear = Heard.line(
        Lines.watch[0]
            .replacingOccurrences(of: #""is":"ask""#, with: #""is":"yourTurn""#)
            .replacingOccurrences(of: #""is":"permission""#, with: #""is":"yourTurn""#)
    )
}
