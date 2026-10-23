import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// Snooze in the SitRep window, over what the real CLI printed (`Lines.snoozed`): Snoozed in the sidebar after Your
/// turn and before Projects, folded at first, a session in it and in Needs you a row in each, each its own pick, which
/// shows the same page; a pick from outside the list landing outside Snoozed unless the session has no other row; and
/// the session's page, its asks asleep after those waiting, each card asleep saying when it wakes.
struct SnoozedWindowTests {
    private static let session = "sr-4g01a7"
    /// When the real `watch` printed its first line here: 08:45 in London on Friday 23 October 2026.
    private static let now = Date(timeIntervalSince1970: 1_792_741_527.619)
    private static let boards = [session: Lines.snoozedBoard]

    /// `watch`'s line at this place, heard on its own.
    private static func line(_ place: Int) -> LastBoard {
        heard(.line(Lines.snoozed[place]))
    }

    /// A window open on `watch`'s first line, its session's board read.
    private static func opened(_ last: LastBoard = line(0)) -> WindowRun {
        let run = WindowRun(wall: { Self.now })

        _ = run.show(last, at: Self.now, reducesMotion: false)
        answer(run.open(), in: run, with: boards)
        return run
    }

    private static func ids(_ run: WindowRun) -> [Sidebar.Line.ID] {
        run.sidebar(at: Self.now).lines.map(\.id)
    }

    private static func row(_ pick: Pick, in run: WindowRun) throws -> Listed.Row {
        try #require(run.listed(at: Self.now).rows.first { $0.pick == pick })
    }

    // MARK: The sidebar

    @Test func snoozedComesAfterTheSessionsBeforeProjectsFoldedAtFirstCountingItsAsks() throws {
        let run = Self.opened()
        let heading = run.sidebar(at: Self.now).lines.compactMap { line -> Sidebar.Heading? in
            if case let .heading(heading) = line, heading.fold == .section(.snoozed) {
                return heading
            }
            return nil
        }.first

        #expect(Self.ids(run) == [
            .fold(.section(.needsYou)), .pick(.session(Self.session)), .fold(.section(.snoozed)), .fold(.projects),
        ])
        #expect(heading == Sidebar.Heading(fold: .section(.snoozed), count: 2, isFolded: true))
        #expect(heading.map(Spoken.heading) == "Snoozed, 2 asks, folded")
    }

    /// Unfolded, the session has a row in Needs you and one in Snoozed, each its own line and its own pick.
    @Test func aSessionInBothHasARowInEachEachItsOwn() throws {
        let run = Self.opened()

        run.toggle(.section(.snoozed))
        #expect(Self.ids(run) == [
            .fold(.section(.needsYou)), .pick(.session(Self.session)), .fold(.section(.snoozed)),
            .pick(.snoozed(Self.session)), .fold(.projects),
        ])

        let asleep = try Self.row(.snoozed(Self.session), in: run)

        #expect(asleep.id == Self.session && asleep.section == .snoozed && asleep.mark == .snoozed)
        #expect(asleep.asks == ["k1", "k2"])
        #expect(asleep.more == "+1")
        #expect(asleep.wakesAt == Date(timeIntervalSince1970: 1_792_741_532))
        #expect(try Self.row(.session(Self.session), in: run).asks == ["k3"])
    }

    @Test func theFilterFindsASnoozedRowByItsAsksWords() {
        let run = Self.opened()

        run.filter = Filter("stage 2")
        #expect(Self.ids(run) == [.fold(.section(.snoozed)), .pick(.snoozed(Self.session))])
    }

    /// Its row reads when it wakes, and offers Wake now; a row of Needs you offers none.
    @Test func voiceOverReadsWhenItWakesAndOffersWakeNow() throws {
        let run = Self.opened()
        let asleep = try Self.row(.snoozed(Self.session), in: run)
        var london = Calendar(identifier: .gregorian)

        london.timeZone = TimeZone(identifier: "Europe/London")!
        #expect(Spoken.row(asleep, at: Self.now, in: london) == [
            "2 asks, Review the plan, Pick when stage 2 runs, Harness, Finish the Harness modernisation, away",
            "wakes 08:45",
        ].joined(separator: ", "))
        #expect(Spoken.wake(asleep) == "Wake now")
        #expect(Spoken.wake(try Self.row(.session(Self.session), in: run)) == nil)
    }

    /// Woken at its time, k1's line arrives in Needs you, its row washing; the Snoozed row never washes.
    @Test func aWakeAtItsTimeWashesItsRowInNeedsYouAndNotItsRowInSnoozed() throws {
        let run = Self.opened()

        _ = run.show(heard(.line(Lines.snoozed[0]), .line(Lines.snoozed[1])), at: Self.now, reducesMotion: false)
        #expect(try Self.row(.session(Self.session), in: run).washed == Self.now)
        #expect(try Self.row(.snoozed(Self.session), in: run).washed == nil)
        #expect(try Self.row(.snoozed(Self.session), in: run).lines.allSatisfy { $0.washed == nil })
    }

    // MARK: The pick

    /// Opened, the window picks the session needing Lee by its row in Needs you.
    @Test func aPickFromOutsideTheListLandsOnTheRowOutsideSnoozed() {
        let run = Self.opened()

        #expect(run.pick == .session(Self.session))
        _ = run.pickInList(.snoozed(Self.session), at: Self.now)
        _ = run.pick(.session(Self.session))
        #expect(run.pick == .session(Self.session))
    }

    /// The Snoozed row clicked holds the pick, on the same page as before: what its cards said stays.
    @Test func theRowClickedHoldsThePickOnTheSamePage() throws {
        let run = Self.opened()
        let k3 = AskAddress(session: Self.session, ask: "k3")

        _ = run.snoozed(k3, .refused("k3 is already closed."))
        _ = run.pickInList(.snoozed(Self.session), at: Self.now)

        let page = try #require(run.page(at: Self.now).session)

        #expect(run.pick == .snoozed(Self.session))
        #expect(run.sidebar(at: Self.now).selection(for: run.pick) == .snoozed(Self.session))
        #expect(page.id == Self.session)
        #expect(page.asks.first { $0.id == k3 }?.lines == [.inbox, .notSnoozed("k3 is already closed.")])
    }

    /// A session with no row but its Snoozed one: a pick from outside lands there, and unfolds Snoozed to show it.
    @Test func withNoOtherRowAPickLandsOnTheSnoozedRow() {
        let run = Self.opened(Self.snoozedAlone())

        _ = run.pick(.session(Self.session))
        #expect(run.pick == .snoozed(Self.session))
        #expect(!run.folds.sections.contains(.snoozed))
        #expect(Self.ids(run).contains(.pick(.snoozed(Self.session))))
    }

    /// The pick follows the session from row to row as one goes: to Snoozed as its asks all sleep, and back as they
    /// wake.
    @Test func thePickMovesToTheRowLeftAsItsRowGoes() {
        let run = Self.opened()

        _ = run.show(Self.snoozedAlone(), at: Self.now, reducesMotion: false)
        #expect(run.pick == .snoozed(Self.session))
        _ = run.show(Self.line(2), at: Self.now, reducesMotion: false)
        #expect(run.pick == .session(Self.session))
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
        #expect((page.waiting, page.snoozed) == (1, 2))
    }

    @Test func aSnoozeOrAWakeRefusedIsSaidOnItsCardUntilPressedAgain() throws {
        let run = Self.opened()
        let k3 = AskAddress(session: Self.session, ask: "k3"), k1 = AskAddress(session: Self.session, ask: "k1")
        let lines = { (ask: AskAddress) in run.page(at: Self.now).session?.asks.first { $0.id == ask }?.lines }

        #expect(run.snoozed(k3, .refused("Lee's reply to k3 is on its way: it waits on Lee no more.")).isEmpty)
        #expect(run.woke(k1, .refused("k1 is not snoozed.")).isEmpty)
        #expect(lines(k3) == [.inbox, .notSnoozed("Lee's reply to k3 is on its way: it waits on Lee no more.")])
        #expect(lines(k1) == [.notWoken("k1 is not snoozed.")])

        run.snoozing(k3)
        #expect(lines(k3) == [.inbox])
    }

    /// Written, the session is read again, for its card to go asleep or wake.
    @Test func aSnoozeWrittenReadsTheSessionAgain() {
        let run = Self.opened()

        #expect(run.snoozed(AskAddress(session: Self.session, ask: "k3"), .written).map(\.session) == [Self.session])
        #expect(run.woke(AskAddress(session: Self.session, ask: "k1"), .written).map(\.session) == [Self.session])
    }

    /// A project's page lists the asks asleep among its asks.
    @Test func aProjectsPageListsItsAsksAsleepAmongItsAsks() throws {
        let run = Self.opened()

        answer(run.pick(.project("harness")), in: run, with: Self.boards)

        let page = try #require(run.page(at: Self.now).project)

        #expect(Set(page.asks.map(\.card.id.ask)) == ["k1", "k2", "k3"])
        #expect(page.asks.filter { $0.card.snoozedUntil != nil }.map(\.card.id.ask).sorted() == ["k1", "k2"])
    }

    @Test func itsWords() {
        #expect(Words.line(.notSnoozed("k1 is already closed.")) == (nil, "Not snoozed: k1 is already closed."))
        #expect(Words.line(.notWoken("k1 is not snoozed.")) == (nil, "Not woken: k1 is not snoozed."))
        #expect(Words.button(.snooze) == "Snooze")
        #expect(Words.snoozed(0) == nil)
        #expect(Words.snoozed(2) == "2 snoozed")
        #expect(Words.snoozedUntil("Sat 09:00") == "Snoozed until Sat 09:00")
        #expect(Spoken.heading("Asks", note: "1 waiting, 2 snoozed") == "Asks, 1 waiting, 2 snoozed")
    }

    /// The first line with its Needs you row gone, as its last waiting ask snoozed would leave it.
    private static func snoozedAlone() -> LastBoard {
        heard(.line(edited(Lines.snoozed[0]) { board in
            board["rows"] = []
            board["head"] = ["needYou": 0, "sessions": 0]
        }))
    }
}
