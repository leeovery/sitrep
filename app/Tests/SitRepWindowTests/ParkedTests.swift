import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// Parked, its list and the item beside it (A4 revised), over what the real CLI printed (`Lines.parked`: Contoso's
/// Onboarding flow, an item parked; Fabrikam's Release notes, none; Northwind's Ledger export, two) and boards built as
/// busy as Lee's grows: grouped by project in `watch`'s order, each project's oldest first; narrowed to a project or a
/// session; filtered; stepped through; held under the pointer; and the item's page.
struct ParkedTests {
    private static let listed = Listed(heard(.line(Lines.parked[0])))

    private static let welcome = ListPick.parked(session: "sr-ctnbd2", id: "dk44")
    private static let currency = ListPick.parked(session: "sr-nwdgr4", id: "77k4")
    private static let retry = ListPick.parked(session: "sr-nwdgr4", id: "3k0a")
    /// When Handle multi-currency rows was parked.
    private static let currencyAt = Date(timeIntervalSince1970: 1_793_803_255.257)

    private static func parked(
        _ listed: Listed = listed, filter: Filter = Filter(), scope: ParkedScope = .all
    ) -> PlaceList {
        PlaceList(.parked, in: listed, filter: filter, scope: scope)
    }

    private static func headings(_ list: PlaceList) -> [String] {
        list.items.compactMap { item in
            if case let .heading(heading) = item {
                return "\(heading.name) \(heading.count)"
            }
            return nil
        }
    }

    /// The window open on `watch`'s first line over the parked board, or the line given.
    private static func opened(on line: Heard = .line(Lines.parked[0])) -> WindowRun {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(line), at: printedAt, reducesMotion: false)
        run.open()
        return run
    }

    // MARK: The list

    /// Contoso then Northwind, as `watch` orders them, Fabrikam, which parked nothing, with no heading; Northwind's
    /// two the oldest first.
    @Test func itIsGroupedByProjectInWatchsOrderEachProjectsOldestFirst() {
        let list = Self.parked()

        #expect(list.picks == [Self.welcome, Self.currency, Self.retry])
        #expect(Self.headings(list) == ["Contoso 1", "Northwind 2"])
        #expect(list.items.map(\.id) == [
            .heading("contoso"), .pick(Self.welcome), .heading("northwind"), .pick(Self.currency), .pick(Self.retry),
        ])
        #expect(list.fold == nil)
    }

    /// Two sessions of one project take turns, by when each item was parked, not session by session.
    @Test func withinAProjectItsSessionsItemsTakeTurnsOldestFirst() {
        let first = Built(id: "n1", project: "northwind", parked: [300, 100])
        let second = Built(id: "n2", project: "northwind", parked: [200, 50])

        #expect(Self.parked(Built.listed([first, second])).picks == [
            first.parkedPick(0), second.parkedPick(0), first.parkedPick(1), second.parkedPick(1),
        ])
    }

    /// A row carries its item, its session's name and its project's.
    @Test func aRowCarriesItsItemAndItsSessionsNames() throws {
        guard case let .parked(item) = try #require(Self.parked().row(Self.currency)) else {
            throw NotParked()
        }

        #expect(item.item.title == "Handle multi-currency rows")
        #expect(item.item.where == "After the first export ships")
        #expect(item.item.ref == "docs/export.md")
        #expect(item.sessionName == "Ledger export")
        #expect(item.projectName == "Northwind")
    }

    private struct NotParked: Error {}

    /// Sessions share ids, as core's are unique only within a session: each row, and its pick, keys on both.
    @Test func itemsKeyOnTheirSessionAndTheirIdAcrossSessionsThatShareAnId() throws {
        let first = Built(id: "n1", project: "northwind", parked: [100])
        let second = Built(id: "n2", project: "northwind", parked: [50])
        let list = Self.parked(Built.listed([first, second]))

        #expect(list.picks == [.parked(session: "n1", id: "p1"), .parked(session: "n2", id: "p1")])
        #expect(Set(list.items.map(\.id)).count == list.items.count)
        #expect(try #require(list.selection(of: second.parkedPick(0))).session == "n2")
        #expect(list.position(of: second.parkedPick(0)) == PlaceList.Position(index: 2, count: 2))
    }

    /// A parked row has no button nor anything to snooze, and is its session's.
    @Test func aParkedRowJumpsNowhereAndSnoozesNothing() throws {
        let row = try #require(Self.parked().row(Self.retry))

        #expect(!row.jumps)
        #expect(row.snoozable == nil)
        #expect(row.row == nil)
        #expect(row.session == "sr-nwdgr4")
    }

    // MARK: Counts, scope and the filter

    /// The place counts every item on the board, whatever the filter or the scope narrows its list to.
    @Test func theCountIsEveryItemOnTheBoard() {
        #expect(Places(Self.listed).count(of: .parked) == 3)
        #expect(Places(Self.listed, filter: Filter("welcome")).count(of: .parked) == 3)
        #expect(Self.parked().rows.count == 3)
    }

    @Test func narrowedToAProjectItListsItsItemsAlone() {
        let list = Self.parked(scope: .project("northwind"))

        #expect(list.picks == [Self.currency, Self.retry])
        #expect(Self.headings(list) == ["Northwind 2"])
    }

    @Test func narrowedToASessionItListsItsItemsAlone() {
        let first = Built(id: "n1", project: "northwind", parked: [300, 100])
        let second = Built(id: "n2", project: "northwind", parked: [200])
        let list = Self.parked(Built.listed([first, second]), scope: .session("n1"))

        #expect(list.picks == [first.parkedPick(0), first.parkedPick(1)])
        #expect(Self.headings(list) == ["Northwind 2"])
    }

    /// An item stays while every word typed appears in its title, its session's name or its project's; not in its
    /// `where`, which its row does not show. A heading counts the items the filter keeps.
    @Test func theFilterKeepsAnItemByItsTitleItsSessionsNameOrItsProjects() {
        #expect(Self.parked(filter: Filter("welcome")).picks == [Self.welcome])
        #expect(Self.parked(filter: Filter("ledger")).picks == [Self.currency, Self.retry])
        #expect(Self.parked(filter: Filter("contoso")).picks == [Self.welcome])
        #expect(Self.parked(filter: Filter("north retry")).picks == [Self.retry])
        #expect(Self.parked(filter: Filter("ships")).isEmpty)
        #expect(Self.headings(Self.parked(filter: Filter("retry"))) == ["Northwind 1"])
    }

    @Test func aFilterThatKeepsNoItemSaysSo() {
        #expect(Words.noMatch(Filter("ledgr"), on: .parked) == "Nothing parked matches “ledgr”")
        #expect(Words.noMatch(Filter("ledgr"), on: .working) == "No sessions match “ledgr”")
    }

    // MARK: A board as busy as Lee's

    /// 120 items in 25 projects, each project under its heading in `watch`'s order, not by name.
    @Test func aBusyBoardIsEveryItemUnderItsProjectsHeadingInWatchsOrder() throws {
        let list = Self.parked(Built.listed(Built.parkedBoard))
        let order = (0 ..< 25).map { String(format: "P%02d", $0 * 7 % 25 + 1) }
        let first = try #require(Built.parkedBoard.first)
        let partner = try #require(Built.parkedBoard.dropFirst().first)

        #expect(list.rows.count == 120)
        #expect(Self.headings(list).map { String($0.prefix(3)) } == order)
        #expect(Self.headings(list).first == "P01 6")
        #expect(Self.headings(list).last == "\(order[24]) 3")
        #expect(Array(list.picks.prefix(6)) == [
            first.parkedPick(0), partner.parkedPick(0), first.parkedPick(1), partner.parkedPick(1),
            first.parkedPick(2), partner.parkedPick(2),
        ])
        #expect(Set(list.items.map(\.id)).count == list.items.count)
    }

    /// ↓ from nothing picked goes through every item in the list's order, the toolbar's position following, and
    /// nowhere past the last; ↑ back from there.
    @Test func onABusyBoardStepsGoThroughEveryItemAndThePositionFollows() throws {
        let run = Self.opened(on: Built.printed(Built.parkedBoard))
        let picks = Self.parked(Built.listed(Built.parkedBoard)).picks

        run.click(.place(.parked))
        #expect(run.toolbar.listing?.position == nil)
        for (place, pick) in picks.enumerated() {
            run.step(down: true, at: printedAt)
            #expect(run.location.picked?.pick == pick)
            #expect(run.toolbar.listing?.position?.text == "\(place + 1) / 120")
        }
        #expect(run.toolbar.listing?.canStepDown == false)
        run.step(down: true, at: printedAt)
        #expect(run.location.picked?.pick == picks.last)
        run.step(down: false, at: printedAt)
        #expect(run.location.picked?.pick == picks[118])
    }

    /// The picked item gone from the board, its pick stands where it stood: no position, ↓ to the item after it and ↑
    /// to the one before it.
    @Test func fromAPickThatLeftStepsGoOnFromWhereItStood() throws {
        var board = Built.parkedBoard
        let first = board[0], partner = board[1]
        let run = Self.opened(on: Built.printed(board))

        run.click(.place(.parked))
        run.pickInList(first.parkedPick(2), at: printedAt)
        board[0].parked.removeLast()
        run.settle(at: printedAt.addingTimeInterval(2))
        run.show(heard(Built.printed(board)), at: printedAt.addingTimeInterval(2), reducesMotion: false)

        #expect(run.location.picked?.pick == first.parkedPick(2))
        #expect(run.toolbar.listing?.position == nil)
        #expect(run.toolbar.listing?.canStepUp == true)
        run.step(down: true, at: printedAt.addingTimeInterval(2))
        #expect(run.location.picked?.pick == partner.parkedPick(2))
        #expect(run.toolbar.listing?.position?.text == "5 / 119")
    }

    // MARK: Held still

    /// Under the pointer the list keeps its projects where they were as `watch` reorders them, an item new on the
    /// board going in under its own project's heading; a second after the pointer leaves, `watch`'s order.
    @Test func theListHoldsStillUnderThePointerKeepingEachProjectsItemsTogether() {
        let north = Built(id: "n1", project: "northwind", parked: [100, 50])
        let contoso = Built(id: "c1", project: "contoso", parked: [90])
        var newer = north
        let run = Self.opened(on: Built.printed([north, contoso]))

        run.click(.place(.parked))
        run.pointer(over: .list, isIn: true, at: printedAt)
        newer.parked.append(10)
        run.show(heard(Built.printed([contoso, newer])), at: printedAt, reducesMotion: false)

        let held = run.list(at: printedAt)

        #expect(held.map(Self.headings) == ["Northwind 3", "Contoso 1"])
        #expect(held?.picks == [north.parkedPick(0), north.parkedPick(1), north.parkedPick(2), contoso.parkedPick(0)])
        run.pointer(over: .list, isIn: false, at: printedAt)
        run.settle(at: printedAt.addingTimeInterval(1))
        #expect(run.list(at: printedAt).map(Self.headings) == ["Contoso 1", "Northwind 3"])
    }

    /// Held under the pointer, an item new to the board that is its project's oldest goes in after the one `watch` has
    /// before it, another project's: still each project's items show together, under one heading, and step as they
    /// show.
    @Test func anItemNewToTheBoardOlderThanItsProjectsOthersStaysWithThemWhileHeld() throws {
        let alpha = Built(id: "a1", project: "alpha", parked: [100])
        let yankee = Built(id: "y1", project: "yankee", parked: [80])
        let reopened = Built(id: "a2", project: "alpha", parked: [150])
        let run = Self.opened(on: Built.printed([alpha, yankee]))

        run.click(.place(.parked))
        run.pointer(over: .list, isIn: true, at: printedAt)
        run.show(heard(Built.printed([yankee, reopened, alpha])), at: printedAt, reducesMotion: false)

        let held = try #require(run.list(at: printedAt))

        #expect(held.items.map(\.id) == [
            .heading("alpha"), .pick(alpha.parkedPick(0)), .pick(reopened.parkedPick(0)), .heading("yankee"),
            .pick(yankee.parkedPick(0)),
        ])
        #expect(held.picks == [alpha.parkedPick(0), reopened.parkedPick(0), yankee.parkedPick(0)])
        run.pointer(over: .list, isIn: false, at: printedAt)
        run.settle(at: printedAt.addingTimeInterval(1))
        #expect(run.list(at: printedAt)?.picks == [yankee.parkedPick(0), reopened.parkedPick(0), alpha.parkedPick(0)])
    }

    // MARK: Opened narrowed

    /// A project's "N parked" opens Parked narrowed to it, a step: its items alone, the toolbar's title naming the
    /// project. A click on Parked clears the narrowing, as another step; Back returns to the narrowing, then to the
    /// project's page.
    @Test func aProjectsParkedOpensParkedNarrowedToItWhichThePlaceClears() {
        let run = Self.opened()

        run.click(.project("northwind"))
        run.go(to: .place(.parked, scope: .project("northwind")), by: .projectParked)
        #expect(run.list(at: printedAt)?.picks == [Self.currency, Self.retry])
        #expect(run.toolbar.title == "Parked · Northwind")
        #expect(run.toolbar.canGoBack)

        run.click(.place(.parked))
        #expect(run.location == .place(.parked))
        #expect(run.list(at: printedAt)?.picks == [Self.welcome, Self.currency, Self.retry])
        #expect(run.toolbar.title == "Parked")

        run.goBack()
        #expect(run.location == .place(.parked, scope: .project("northwind")))
        #expect(run.toolbar.title == "Parked · Northwind")
        run.goBack()
        #expect(run.location == .project("northwind"))
    }

    /// A session's "later N parked" narrows Parked to the session, the title naming it; a pick stays within it.
    @Test func aSessionsParkedOpensParkedNarrowedToTheSession() {
        let run = Self.opened()

        run.go(to: .place(.parked, scope: .session("sr-nwdgr4")), by: .sessionParked)
        #expect(run.toolbar.title == "Parked · Ledger export")
        run.step(down: true, at: printedAt)
        run.step(down: true, at: printedAt)
        #expect(run.location == .place(
            .parked, picked: Selection(pick: Self.retry, session: "sr-nwdgr4"), scope: .session("sr-nwdgr4")
        ))
        #expect(run.toolbar.listing?.position?.text == "2 / 2")
    }

    // MARK: The item's page

    /// The item picked shows beside the list: its title, `where` and `ref`, its project, and the session it was
    /// parked from, which the window follows, with its now line and its asks waiting.
    @Test func thePickedItemShowsBesideTheListAndItsSessionIsFollowed() throws {
        let run = Self.opened()

        run.click(.place(.parked))
        run.pickInList(Self.currency, at: printedAt)
        run.settle(at: printedAt.addingTimeInterval(1))

        let page = try #require(run.page(at: printedAt).parked)

        #expect(page.id == Self.currency)
        #expect(page.item.title == "Handle multi-currency rows")
        #expect(page.item.where == "After the first export ships")
        #expect(page.item.ref == "docs/export.md")
        #expect(page.projectKey == "northwind")
        #expect(page.projectName == "Northwind")
        #expect(page.from == ParkedPage.From(
            id: "sr-nwdgr4", name: "Ledger export", mark: .away, isAway: true, now: "Mapping the ledger columns", asks: 0
        ))
        #expect(page.from.parts == ["Mapping the ledger columns"])
        #expect(!page.hasBoard)
        #expect(page.since.isEmpty)
        #expect(run.following == ["sr-nwdgr4"])
    }

    /// Contoso's session has a choice waiting and no now line: "1 ask", and the away ring for its mark.
    @Test func parkedFromSaysTheSessionsAsksWaiting() throws {
        let run = Self.opened()

        run.click(.place(.parked))
        run.pickInList(Self.welcome, at: printedAt)

        let from = try #require(run.page(at: printedAt).parked).from

        #expect(from.parts == ["1 ask"])
        #expect(from.mark == .awayAsk)
    }

    /// Since it was parked: the session's log lines after the item was parked, the newest first, none before it.
    @Test func sinceItWasParkedIsTheLogsLinesAfterIt() throws {
        let run = Self.pickedCurrency(carrying: [60, 30, -10])
        let page = try #require(run.page(at: printedAt).parked)

        #expect(page.hasBoard)
        #expect(page.since.map(\.text) == ["Note 0", "Note 1"])
        #expect(!page.isSinceCut)
    }

    /// A board carries the 8 newest lines: every one after the item was parked, more may have come since than show.
    @Test func sinceItWasParkedSaysWhereTheLogsCapCutsIt() throws {
        let cut = try #require(Self.pickedCurrency(carrying: (1 ... 8).reversed().map { Double($0) }).page(at: printedAt).parked)
        let whole = try #require(
            Self.pickedCurrency(carrying: (0 ... 7).reversed().map { Double($0) - 0.5 }).page(at: printedAt).parked
        )

        #expect(cut.since.count == 8)
        #expect(cut.isSinceCut)
        #expect(whole.since.count == 7)
        #expect(!whole.isSinceCut)
    }

    /// Two sessions parked items of one id: the second's picked, its page is its item, of its session.
    @Test func ofTwoSessionsSharingAnIdThePageIsThePickedSessionsItem() throws {
        let first = Built(id: "n1", project: "northwind", parked: [100])
        let second = Built(id: "n2", project: "northwind", parked: [50])
        let run = Self.opened(on: Built.printed([first, second]))

        run.click(.place(.parked))
        run.pickInList(second.parkedPick(0), at: printedAt)

        let page = try #require(run.page(at: printedAt).parked)

        #expect(page.id == .parked(session: "n2", id: "p1"))
        #expect(page.item.title == "Parked 1 of n2")
        #expect(page.from.name == "Session n2")
    }

    /// From an item picked on Parked narrowed, Back to its session pushes the session's page, Parked staying picked in
    /// the sidebar; Back returns to Parked narrowed, the item picked as it was.
    @Test func backToItsSessionIsAStepBackReturnsFromToTheItem() {
        let run = Self.opened()
        let narrowed = Location.place(
            .parked, picked: Selection(pick: Self.retry, session: "sr-nwdgr4"), scope: .project("northwind")
        )

        run.go(to: .place(.parked, scope: .project("northwind")), by: .projectParked)
        run.pickInList(Self.retry, at: printedAt)
        run.go(to: .session("sr-nwdgr4", from: .place(.parked)), by: .backToSession)
        #expect(run.location.root == .place(.parked))
        #expect(run.page(at: printedAt).session?.id == "sr-nwdgr4")

        run.goBack()
        #expect(run.location == narrowed)
        #expect(run.toolbar.listing?.position?.text == "2 / 2")
        #expect(run.page(at: printedAt).parked?.id == Self.retry)
    }

    /// A parked item's page is a page of its own: another item of the same session picked turns the page, closing what
    /// the last one opened, as a session's detail and its item's are two pages too.
    @Test func anotherItemOfTheSameSessionTurnsThePage() throws {
        let run = Self.pickedCurrency(carrying: [60, 30])
        let note = Item.note("sr-nwdgr4:n0")

        run.toggle(note)
        #expect(try #require(run.page(at: printedAt).parked).opened == [note])
        run.pickInList(Self.retry, at: printedAt)
        #expect(try #require(run.page(at: printedAt).parked).opened.isEmpty)
        #expect(Location.place(.needsYou, picked: Selection(pick: .line("ask:sr-nwdgr4:k1"), session: "sr-nwdgr4")).leaf
            != Location.place(.parked, picked: Selection(pick: Self.retry, session: "sr-nwdgr4")).leaf)
    }

    /// The item gone from the board, picked up or dropped, the page says so, the pick standing.
    @Test func anItemGoneFromTheBoardSaysItIsNoLongerParked() {
        let north = Built(id: "n1", project: "northwind", parked: [100, 50])
        var unparked = north
        let run = Self.opened(on: Built.printed([north]))

        run.click(.place(.parked))
        run.pickInList(north.parkedPick(1), at: printedAt)
        unparked.parked.removeLast()
        run.show(heard(Built.printed([unparked])), at: printedAt, reducesMotion: false)

        #expect(run.location.picked?.pick == north.parkedPick(1))
        #expect(run.page(at: printedAt) == .empty("No longer parked."))
    }

    /// Ledger export's Handle multi-currency rows picked, then `watch`'s second line, its board carrying log lines, the
    /// newest first, each so many seconds after the item was parked.
    private static func pickedCurrency(carrying seconds: [Double]) -> WindowRun {
        let run = opened()

        run.click(.place(.parked))
        run.pickInList(currency, at: printedAt)
        run.show(heard(.line(Lines.parked[0]), withLog(seconds)), at: printedAt, reducesMotion: false)
        return run
    }

    private static func withLog(_ seconds: [Double]) -> Heard {
        var line = try! JSONSerialization.jsonObject(with: Data(Lines.parked[1].utf8)) as! [String: Any]
        var boards = line["boards"] as! [String: Any]
        var board = boards["sr-nwdgr4"] as! [String: Any]

        board["log"] = seconds.enumerated().map { place, second -> [String: Any] in
            [
                "kind": "note", "id": "n\(place)", "text": "Note \(place)", "detail": [String](), "ref": NSNull(),
                "by": "claude", "at": Int64(((currencyAt.timeIntervalSince1970 + second) * 1000).rounded()),
            ]
        }
        boards["sr-nwdgr4"] = board
        line["boards"] = boards
        return .line(String(decoding: try! JSONSerialization.data(withJSONObject: line), as: UTF8.self))
    }

    // MARK: In words

    @Test func voiceOverReadsARowItsHeadingAndWhereItWasParkedFrom() throws {
        let row = try #require(Self.parked().row(Self.retry))
        let at = Date(timeIntervalSince1970: 1_793_803_255.326)

        #expect(Spoken.row(row, at: at.addingTimeInterval(3 * 3600)) == "Retry failed uploads, Northwind, Ledger export, 3 hours")
        #expect(Spoken.heading(PlaceList.Heading(project: "northwind", name: "Northwind", count: 2)) == "Northwind, 2 items")
        #expect(Spoken.parkedFrom(ParkedPage.From(
            id: "sr-nwdgr4", name: "Ledger export", mark: .away, isAway: true, now: "Mapping the ledger columns", asks: 2
        )) == "Ledger export, away, Mapping the ledger columns, 2 asks")
        #expect(Spoken.place(.parked, count: 3) == "Parked, 3 items")
    }

    /// "Parked 3 hours ago", as A4 draws it, with no "as it wrote": nothing records what the session was writing.
    @Test func whenItWasParkedIsInWholeWords() {
        #expect(Words.parkedAgo(Self.currencyAt, at: Self.currencyAt.addingTimeInterval(3 * 3600)) == "Parked 3 hours ago")
        #expect(Words.parkedAgo(Self.currencyAt, at: Self.currencyAt.addingTimeInterval(20)) == "Parked just now")
        #expect(Words.parkedAgo(Self.currencyAt, at: Self.currencyAt.addingTimeInterval(60)) == "Parked 1 minute ago")
    }
}
