import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// Snooze in the SitRep window, over what the real CLI printed (`Lines.snoozed`): Needs you's asks asleep at its foot
/// under "N snoozed", folded at first, a row per ask, the soonest to wake first; a snoozed ask picked and woken picked
/// as its line; a line picked and snoozed staying picked, gone from the list; and the session's page, its asks asleep
/// after those waiting, each card asleep saying when it wakes.
struct SnoozedWindowTests {
    private static let session = "sr-4g01a7"
    /// Harness's ask waiting, and its two asleep, Review the plan waking first.
    private static let k3 = ListPick.line("ask:sr-4g01a7:k3")
    private static let k1 = ListPick.snoozed("ask:sr-4g01a7:k1")
    private static let k2 = ListPick.snoozed("ask:sr-4g01a7:k2")
    /// When the real `watch` printed its first line here: 08:45 in London on Friday 23 October 2026.
    private static let now = Date(timeIntervalSince1970: 1_792_741_527.619)
    private static let boards: [String: String?] = [session: Lines.snoozedBoard]

    /// `watch`'s line at this place.
    private static func line(_ place: Int) -> Heard {
        .line(Lines.snoozed[place])
    }

    /// A window open on `watch`'s first line, unless another, then its session's board, as the next line carries it.
    private static func opened(_ line: Heard = line(0)) -> WindowRun {
        let run = WindowRun(wall: { Self.now })

        run.show(heard(line), at: Self.now, reducesMotion: false)
        run.open()
        take(boards, in: run, on: line, at: Self.now)
        return run
    }

    private static func list(_ run: WindowRun) throws -> PlaceList {
        try #require(run.list(at: Self.now))
    }

    private static func line(_ pick: ListPick, in run: WindowRun) throws -> PlaceList.LineRow {
        try #require(try list(run).row(pick)?.lineRow)
    }

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    // MARK: The list

    /// Opened on Needs you, its one line waiting picked, its two asks asleep folded under "2 snoozed".
    @Test func needsYouEndsInItsAsksAsleepFoldedUnderNSnoozed() throws {
        let run = Self.opened()
        let list = try Self.list(run)
        let fold = try #require(list.fold)

        #expect(run.location.picked?.pick == Self.k3)
        #expect(list.items.map(\.id) == [.pick(Self.k3), .fold(.snoozed)])
        #expect(fold.title == "2 snoozed")
        #expect(Spoken.fold(fold) == "2 snoozed, folded")
        #expect(run.places.count(of: .needsYou) == 1)
    }

    /// Open, a row per ask asleep, the soonest to wake first, each its own and offering only its own ask; folded
    /// again as the window opens afresh.
    @Test func nSnoozedOpensInPlaceARowPerAskAndFoldsAgainAsTheWindowOpens() throws {
        let run = Self.opened()

        run.toggleFold(of: .needsYou)
        #expect(try Self.list(run).picks == [Self.k3, Self.k1, Self.k2])

        let asleep = try Self.line(Self.k1, in: run)

        #expect(asleep.isAsleep && asleep.mark == .snoozed)
        #expect(asleep.asks == ["k1"])
        #expect(asleep.line.wakesAt == Date(timeIntervalSince1970: 1_792_741_532))
        #expect(try Self.line(Self.k3, in: run).asks == ["k3"])
        run.close()
        run.open()
        #expect(try Self.list(run).picks == [Self.k3])
    }

    @Test func theFilterFindsAnAskAsleepByItsWords() throws {
        let run = Self.opened()

        run.filter = Filter("stage 2")
        #expect(try Self.list(run).items.map(\.id) == [.fold(.snoozed), .pick(Self.k2)])
    }

    /// An ask asleep reads when it wakes, and offers Wake now; a line waiting offers none.
    @Test func voiceOverReadsWhenAnAskAsleepWakesAndOffersWakeNow() throws {
        let run = Self.opened()

        run.toggleFold(of: .needsYou)

        let asleep = try Self.line(Self.k1, in: run)

        #expect(Spoken.line(asleep, at: Self.now, in: Self.london)
            == "Review the plan, Harness, Finish the Harness modernisation, away, wakes 08:45")
        #expect(Spoken.wake(asleep) == "Wake now")
        #expect(Spoken.wake(try Self.line(Self.k3, in: run)) == nil)
    }

    /// A line that is an ask offers its menu's three snoozes, each saying when it would wake; an ask asleep and a
    /// window's stop offer none.
    @Test func voiceOverOffersALineThatIsAnAskItsSnoozes() throws {
        let run = Self.opened()
        let stopped = Listed.Row(
            id: "sr-kit", name: "Kit", project: "Kit", section: .needsYou, mark: .needs, isAway: false, since: Self.now,
            lines: [Listed.Line(id: "stop:sr-kit:w1", lead: "Allow Bash", code: "gh pr create", more: nil, since: Self.now)]
        )
        let snoozes = { (line: PlaceList.LineRow) in
            SnoozeChoice.allCases.compactMap { Spoken.snooze($0, of: line, at: Self.now, in: Self.london) }
        }

        run.toggleFold(of: .needsYou)
        #expect(snoozes(try Self.line(Self.k3, in: run)) == [
            "Snooze later today, wakes 11:45", "Snooze tomorrow, wakes Saturday 09:00",
            "Snooze next week, wakes Monday 09:00",
        ])
        #expect(snoozes(try Self.line(Self.k1, in: run)).isEmpty)
        #expect(snoozes(PlaceList.LineRow(session: stopped, line: stopped.lines[0])).isEmpty)
    }

    /// Woken at its time, k1's line comes into Needs you washing; the asks asleep never wash.
    @Test func aWakeAtItsTimeWashesItsLineInNeedsYouAndNoAskAsleep() throws {
        let run = Self.opened()

        run.show(heard(.line(Lines.snoozed[0]), .line(Lines.snoozed[1])), at: Self.now, reducesMotion: false)
        run.toggleFold(of: .needsYou)
        #expect(try Self.line(.line("ask:sr-4g01a7:k1"), in: run).line.washed == Self.now)
        #expect(try Self.line(Self.k2, in: run).line.washed == nil)
    }

    // MARK: The pick

    /// Core gives an ask one key asleep and awake: picked under "N snoozed" and woken, it is picked as its line.
    @Test func anAskAsleepPickedAndWokenIsPickedAsItsLine() throws {
        let run = Self.opened()

        run.toggleFold(of: .needsYou)
        run.pickInList(Self.k1, at: Self.now)
        run.show(heard(Self.line(1)), at: Self.now, reducesMotion: false)
        #expect(run.location.picked?.pick == .line("ask:sr-4g01a7:k1"))
        #expect(try Self.list(run).row(run.location.picked?.pick) != nil)
    }

    /// Snoozing is putting it out of the way: the line picked and snoozed stays picked, gone from the list, its page
    /// staying.
    @Test func theLinePickedAndSnoozedStaysPickedGoneFromTheList() throws {
        let run = Self.opened()

        run.show(heard(Self.snoozedAlone()), at: Self.now, reducesMotion: false)
        #expect(run.location.picked?.pick == Self.k3)
        #expect(try Self.list(run).row(Self.k3) == nil)
        #expect(run.page(at: Self.now).session?.id == Self.session)
    }

    /// Its asks all asleep, "Open in SitRep" opens its project's page, then its own over it.
    @Test func openedFromOutsideWithItsAsksAllAsleepItsPageIsPushedOverItsProjects() {
        let run = Self.opened(Self.snoozedAlone())

        run.land(Self.session)
        #expect(run.location == .session(Self.session, from: .project("harness")))
        run.goBack()
        #expect(run.location == .project("harness"))
    }

    /// An ask asleep clicked picks its row, on the same page as before: what its cards said stays.
    @Test func anAskAsleepClickedPicksItsRowOnTheSamePage() throws {
        let run = Self.opened()
        let k3 = AskAddress(session: Self.session, ask: "k3")

        _ = run.snoozed(k3, .refused("k3 is already closed."))
        run.toggleFold(of: .needsYou)
        run.pickInList(Self.k1, at: Self.now)

        let page = try #require(run.page(at: Self.now).session)

        #expect(run.location.picked?.pick == Self.k1)
        #expect(page.id == Self.session)
        #expect(page.asks.first { $0.id == k3 }?.lines == [.inbox, .notSnoozed("k3 is already closed.")])
    }

    // MARK: The session's page

    /// Those waiting first, then those asleep, the soonest to wake first; asleep, no buttons, but when it wakes.
    @Test func itsAsksAsleepComeAfterThoseWaitingEachSayingWhenItWakes() throws {
        let page = try #require(Self.opened().page(at: Self.now).session)

        #expect(page.asks.map(\.id.ask) == ["k3", "k1", "k2"])
        #expect(page.asks.map(\.snoozedUntil) == [
            nil, Date(timeIntervalSince1970: 1_792_741_532), Date(timeIntervalSince1970: 1_792_745_127),
        ])
        #expect(page.asks.map(\.buttons) == [[.yes("Go"), .ignore, .snooze], [], []])
        #expect(page.waiting == 1)
    }

    /// An ask asleep picked under "N snoozed" leads the detail as its card asleep, with Wake now in its buttons' place.
    @Test func anAskAsleepPickedLeadsTheDetailAsItsCardAsleep() throws {
        let run = Self.opened()

        run.toggleFold(of: .needsYou)
        run.pickInList(Self.k1, at: Self.now)

        let page = try #require(run.page(at: Self.now).session)
        guard case let .ask(card) = page.lead else {
            Issue.record("No card leads: \(String(describing: page.lead))")
            return
        }

        #expect(card.id == AskAddress(session: Self.session, ask: "k1"))
        #expect(card.snoozedUntil != nil && card.buttons.isEmpty)
    }

    /// k3, the one waiting, closes with nothing holding the page: it leaves, and those asleep stay as they were.
    @Test func anAskAsleepComesThroughTheClosedOnesLeavingAsItWas() throws {
        let run = Self.opened()
        let before = try #require(run.page(at: Self.now).session?.asks.filter { $0.snoozedUntil != nil })
        let closed = edited(Lines.snoozedBoard) { board in
            board["asks"] = (board["asks"] as! [[String: Any]]).filter { $0["id"] as? String != "k3" }
        }

        take([Self.session: closed], in: run, on: Self.line(0), at: Self.now)
        #expect(run.page(at: Self.now).session?.asks == before)
    }

    @Test func aSnoozeOrAWakeRefusedIsSaidOnItsCardUntilPressedAgain() throws {
        let run = Self.opened()
        let k3 = AskAddress(session: Self.session, ask: "k3"), k1 = AskAddress(session: Self.session, ask: "k1")
        let lines = { (ask: AskAddress) in run.page(at: Self.now).session?.asks.first { $0.id == ask }?.lines }

        #expect(!run.snoozed(k3, .refused("Lee's reply to k3 is on its way: it waits on Lee no more.")))
        #expect(!run.woke(k1, .refused("k1 is not snoozed.")))
        #expect(lines(k3) == [.inbox, .notSnoozed("Lee's reply to k3 is on its way: it waits on Lee no more.")])
        #expect(lines(k1) == [.notWoken("k1 is not snoozed.")])

        run.snoozing(k3)
        #expect(lines(k3) == [.inbox])
    }

    /// Written, `watch` looks at once, for its card to go asleep or wake on the board it carries next.
    @Test func aSnoozeOrAWakeWrittenAsksForALookNow() {
        let run = Self.opened()

        #expect(run.snoozed(AskAddress(session: Self.session, ask: "k3"), .written))
        #expect(run.woke(AskAddress(session: Self.session, ask: "k1"), .written))
    }

    /// A project's page lists the asks asleep among its asks.
    @Test func aProjectsPageListsItsAsksAsleepAmongItsAsks() throws {
        let run = Self.opened()

        run.click(.project("harness"))
        take(Self.boards, in: run, on: Self.line(0), at: Self.now)

        let page = try #require(run.page(at: Self.now).project)

        #expect(Set(page.asks.map(\.card.id.ask)) == ["k1", "k2", "k3"])
        #expect(page.asks.filter { $0.card.snoozedUntil != nil }.map(\.card.id.ask).sorted() == ["k1", "k2"])
    }

    @Test func itsWords() {
        #expect(Words.line(.notSnoozed("k1 is already closed.")) == (nil, "Not snoozed: k1 is already closed."))
        #expect(Words.line(.notWoken("k1 is not snoozed.")) == (nil, "Not woken: k1 is not snoozed."))
        #expect(Words.button(.snooze) == "Snooze")
        #expect(Words.snoozedUntil("Sat 09:00") == "Snoozed until Sat 09:00")
        #expect(Spoken.heading("Asks", note: "1 waiting", aside: "2 snoozed") == "Asks, 1 waiting, 2 snoozed")
        #expect(Spoken.heading("Asks", note: nil, aside: "1 snoozed") == "Asks, 1 snoozed")
        #expect(Spoken.heading("Status", note: nil, aside: nil) == "Status")
    }

    /// The first line with its Needs you row gone, as its last waiting ask snoozed would leave it.
    private static func snoozedAlone() -> Heard {
        .line(edited(Lines.snoozed[0]) { board in
            board["rows"] = []
            board["head"] = ["needYou": 0, "sessions": 0]
        })
    }
}
