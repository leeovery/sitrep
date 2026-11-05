import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// Where Lee last looked at a session: written as its page stops showing, beside a place's list or filling the window
/// alike, and as the window closes, is minimised or hidden, or the app quits, never for a parked item's page, and kept
/// only for the sessions on the board; then on its page's What happened, the divider above the newest entry from at or
/// before the look, only with entries on both sides of it.
struct YouLookedTests {
    /// A wall clock the test moves.
    private final class Clock {
        var now = printedAt

        func passes(_ seconds: TimeInterval) {
            now = now.addingTimeInterval(seconds)
        }
    }

    /// The window open on `watch`'s first line, landed on the Mac app's newest line, its board carried, and visible.
    private static func shown(looked: LastLooked = LastLooked(), clock: Clock = Clock()) -> WindowRun {
        let run = opened(looked: looked, wall: { clock.now })

        run.window(isVisible: true)
        return run
    }

    /// The Mac app's page filling the window, pushed from its project's.
    private static func full(looked: LastLooked) -> WindowRun {
        let run = shown(looked: looked)

        run.go(to: .session("sr-macapp", from: .project("sitrep")), by: .projectSession)
        take(["sr-macapp": Lines.board], in: run)
        return run
    }

    private static func looked(_ session: String, at time: Date) -> LastLooked {
        LastLooked([session: time])
    }

    // MARK: When it is written

    /// Another session's page shows: the Mac app's page stopped showing then, and that is when Lee looked at it.
    @Test func anotherSessionsPageWritesWhenTheLastStoppedShowing() {
        let clock = Clock()
        let run = Self.shown(clock: clock)

        #expect(run.looked == LastLooked())
        clock.passes(60)
        run.pickInList(.line("ask:sr-dash02:k1"), at: clock.now)
        #expect(run.looked == LastLooked(["sr-macapp": clock.now]))
    }

    /// A place with nothing picked, or a project's page, is no session's: the page showing stops showing.
    @Test(arguments: [Root.place(.yourTurn), .project("sitrep")])
    func aPageOfNoSessionWritesTheLast(root: Root) {
        let clock = Clock()
        let run = Self.shown(clock: clock)

        clock.passes(60)
        run.click(root)
        #expect(run.looked == LastLooked(["sr-macapp": clock.now]))
    }

    /// The session's detail beside the list and its page filling the window are both its page: going from one to the
    /// other, and back, writes nothing.
    @Test func itsDetailAndItsFullPageAreOnePage() {
        let clock = Clock()
        let run = Self.shown(clock: clock)

        clock.passes(60)
        run.go(to: .session("sr-macapp", from: .project("sitrep")), by: .projectSession)
        clock.passes(60)
        run.goBack()
        #expect(run.looked == LastLooked())
        clock.passes(60)
        run.click(.project("kit"))
        #expect(run.looked == LastLooked(["sr-macapp": clock.now]))
    }

    /// Another line of the same session picked is the same page: nothing is written.
    @Test func anotherLineOfTheSameSessionWritesNothing() {
        let run = Self.shown()

        run.pickInList(.line("ask:sr-macapp:k3"), at: printedAt)
        #expect(run.looked == LastLooked())
    }

    /// A parked item's page is not its session's: going from it to its session's page writes nothing, and from its
    /// session's page back to it writes the session's.
    @Test func aParkedItemsPageIsNotItsSessions() {
        let clock = Clock()
        let run = WindowRun(wall: { clock.now })
        let item = ListPick.parked(session: "sr-nwdgr4", id: "77k4")

        run.show(heard(.line(Lines.parked[0])), at: printedAt, reducesMotion: false)
        run.open()
        run.click(.place(.parked))
        run.pickInList(item, at: clock.now)
        run.window(isVisible: true)
        clock.passes(60)
        run.go(to: .session("sr-nwdgr4", from: .place(.parked)), by: .backToSession)
        #expect(run.looked == LastLooked())
        clock.passes(60)
        run.goBack()
        #expect(run.page(at: clock.now).parked != nil)
        #expect(run.looked == LastLooked(["sr-nwdgr4": clock.now]))
        let left = clock.now
        clock.passes(60)
        run.pickInList(.parked(session: "sr-nwdgr4", id: "3k0a"), at: clock.now)
        run.click(.place(.needsYou))
        #expect(run.looked == LastLooked(["sr-nwdgr4": left]))
    }

    /// The ways the window stops showing the page while it stays on it.
    enum Leaving: CaseIterable {
        case closing, minimising, hiding, quitting

        func leave(_ run: WindowRun) {
            switch self {
            case .closing: run.close()
            case .minimising: run.minimise()
            case .hiding: run.window(isVisible: false)
            case .quitting: run.quit()
            }
        }
    }

    /// The window closing, minimised, hidden or covered, or the app quitting: the page showing stops showing then.
    @Test(arguments: Leaving.allCases)
    func theWindowStoppingShowingWritesThePageShowing(leaving: Leaving) {
        let clock = Clock()
        let run = Self.shown(clock: clock)

        clock.passes(60)
        leaving.leave(run)
        #expect(run.looked == LastLooked(["sr-macapp": clock.now]))
    }

    /// Back from the Dock, or uncovered, the page shows again, writing nothing until it stops showing once more; the
    /// window not key still shows it.
    @Test func comingBackWritesNothingUntilThePageStopsShowingAgain() {
        let clock = Clock()
        let run = Self.shown(clock: clock)

        clock.passes(60)
        run.minimise()
        let minimised = clock.now
        clock.passes(60)
        run.restore()
        run.window(isKey: false, at: clock.now)
        #expect(run.looked == LastLooked(["sr-macapp": minimised]))
        clock.passes(60)
        run.window(isVisible: false)
        clock.passes(60)
        run.window(isVisible: true)
        #expect(run.looked == LastLooked(["sr-macapp": clock.now.addingTimeInterval(-60)]))
    }

    // MARK: Pruned

    /// Each board heard keeps only the looks at sessions on it, so a session gone from it leaves nothing behind.
    @Test func eachBoardKeepsOnlyTheSessionsOnIt() {
        let run = Self.shown(looked: LastLooked(["sr-gone00": printedAt, "sr-dash02": printedAt]))

        #expect(run.looked == LastLooked(["sr-dash02": printedAt]))
    }

    /// A session leaving the board while its page shows: its page stops showing, and its look goes with it.
    @Test func aSessionLeavingTheBoardWhileItShowsLeavesNoLook() {
        let first = Built(id: "s1", project: "p1", waiting: [5])
        let second = Built(id: "s2", project: "p1", waiting: [10])
        let run = WindowRun()

        run.show(heard(Built.printed([first, second])), at: printedAt, reducesMotion: false)
        run.open()
        run.land("s1")
        run.window(isVisible: true)
        run.show(heard(Built.printed([second])), at: printedAt, reducesMotion: false)
        #expect(run.looked == LastLooked())
    }

    /// With no board heard, before `watch` prints its first line, nothing has left the board: every look stays.
    @Test func withNoBoardHeardEveryLookStays() {
        let looked = LastLooked(["sr-gone00": printedAt])
        let run = WindowRun(looked: looked)
        var last = LastBoard()

        last.begin()
        run.show(last, at: printedAt, reducesMotion: false)
        run.unrun("No watch")
        #expect(run.looked == looked)
    }

    // MARK: Saved

    @Test func itIsSavedAndReadBack() {
        let defaults = MemoryDefaults()
        let looked = LastLooked(["sr-macapp": printedAt])

        looked.save(in: defaults)
        #expect(LastLooked.read(defaults) == looked)
    }

    /// Nothing saved, or what it cannot read, is no session looked at.
    @Test(arguments: [nil, "{\"sessions\":[1,2]}", "not json"])
    func whatItCannotReadIsNoneLookedAt(saved: String?) {
        let defaults = MemoryDefaults()

        saved.map { defaults.set(Data($0.utf8), forKey: LastLooked.key) }
        #expect(LastLooked.read(defaults) == LastLooked())
    }

    // MARK: Where the divider goes

    /// Entries ten minutes apart, the newest first.
    private static let thread = [20.0, 30, 40, 50].map { minutes(before: $0) }

    /// Above the newest entry from at or before the look, an entry as old as the look among those under it, which are
    /// dimmer.
    @Test(arguments: [(25.0, 1), (30, 1), (35, 2), (45, 3)])
    func itGoesAboveTheNewestEntryAtOrBeforeTheLook(before: Double, newer: Int) throws {
        let looked = try #require(YouLooked(minutes(before: before), over: Self.thread))

        #expect(looked.at == minutes(before: before))
        #expect(looked.newer == newer)
        #expect((0 ..< 4).map(looked.isOlder) == (0 ..< 4).map { $0 >= newer })
    }

    /// Nothing newer than the look, everything newer, or never looked: no divider, and nothing dimmed.
    @Test(arguments: [10.0, 20, 60, nil])
    func withEntriesOnOneSideOnlyThereIsNone(before: Double?) {
        #expect(YouLooked(before.map { minutes(before: $0) }, over: Self.thread) == nil)
        #expect(YouLooked(minutes(before: 10), over: []) == nil)
    }

    /// Beside the list What happened is the log alone: 16 hours, 18 hours and 18 hours 20 ago; a look 17 hours ago
    /// goes under the first.
    @Test func onTheDetailItDividesTheLog() throws {
        let run = Self.shown(looked: Self.looked("sr-macapp", at: minutes(before: 17 * 60)))
        let page = try #require(run.page(at: printedAt).session)

        #expect(page.mode == .detail)
        #expect(page.looked?.newer == 1)
        #expect(page.looked?.at == minutes(before: 17 * 60))
    }

    /// Filling the window its asks are entries too: asked 4 minutes, 3 hours 20 and 5 hours ago; a look 4 hours ago goes
    /// under the second.
    @Test func fillingTheWindowItDividesTheAsksAndTheLogAlike() throws {
        let page = try #require(Self.full(looked: Self.looked("sr-macapp", at: minutes(before: 240))).page(at: printedAt).session)

        #expect(page.mode == .full)
        #expect(page.happened.prefix(3).map(\.id) == ["asked:k1", "asked:k3", "asked:k2"])
        #expect(page.looked?.newer == 2)
    }

    /// A look at another session's page, or none, draws no divider.
    @Test func aLookAtAnotherSessionDrawsNone() throws {
        let run = Self.shown(looked: Self.looked("sr-dash02", at: minutes(before: 17 * 60)))

        #expect(try #require(run.page(at: printedAt).session).looked == nil)
    }

    /// While the page shows, a line written lands above the divider, which holds where it was.
    @Test func entriesArrivingWhileThePageShowsStayAboveIt() throws {
        let at = minutes(before: 17 * 60)
        let run = Self.shown(looked: Self.looked("sr-macapp", at: at))
        let written = edited(Lines.board) { board in
            let note: [String: Any] = [
                "kind": "note", "id": "n3", "text": "Line written meanwhile", "detail": [String](), "ref": NSNull(),
                "by": "w1", "at": (printedAt.timeIntervalSince1970 * 1000).rounded(),
            ]

            board["log"] = [note] + (board["log"] as! [[String: Any]])
        }

        take(["sr-macapp": written], in: run)

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.happened.first?.id == "sr-macapp:n3")
        #expect(page.looked?.newer == 2)
        #expect(page.looked?.at == at)
        #expect(run.looked == Self.looked("sr-macapp", at: at))
    }

    // MARK: In words

    @Test func theDividerSaysWhenInTheWindowsAgeWordsAndToVoiceOverInWholeWords() {
        let at = minutes(before: 120)

        #expect(Words.youLooked(at, at: at.addingTimeInterval(2 * 3600)) == "You looked 2h ago")
        #expect(Words.youLooked(at, at: at.addingTimeInterval(20)) == "You looked just now")
        #expect(Spoken.youLooked(at, at: at.addingTimeInterval(2 * 3600)) == "You looked 2 hours ago")
        #expect(Spoken.youLooked(at, at: at.addingTimeInterval(60)) == "You looked 1 minute ago")
    }
}
