import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepPanelTestSupport
import SitRepTestSupport
import Testing

/// The one fold setting the card and the strip share (14 November 2026), each reading it as it lays out, so a section
/// folded on one is folded on the other at its next frame, and kept; an arrival unfolding Needs you only while Lee
/// has the notch show the board; and the strip's Snoozed marks, its right-click's targets, a menu's hold and its jump.
@MainActor
struct StripFoldingTests {
    // MARK: One setting

    @Test func aSectionFoldedOnTheStripIsFoldedOnTheCardAtItsNextFrame() {
        let folding = Folding(), notch = Self.opened(folding: folding), strip = Self.strip(folding: folding)

        strip.fold(.working, folded: true, Self.at(strip.time))
        #expect(notch.folded.sections == [.working, .snoozed])

        notch.step(Self.at(notch, notch.time + Self.frameMS, Self.onTheNotch))
        #expect(!Self.keys(notch).contains("sr-w"))
        #expect(Self.keys(notch).last == "eyebrow:working")
    }

    @Test func aSectionFoldedOnTheCardIsFoldedOnTheStripAtItsNextFrame() throws {
        let folding = Folding(), notch = Self.opened(folding: folding), strip = Self.strip(folding: folding)

        #expect(try Self.press("eyebrow:working", in: notch) == .fold)
        #expect(strip.strip.layout.counts[.working] == nil)

        strip.step(Self.at(strip.time + Self.frameMS))
        #expect(strip.strip.folded == [.working, .snoozed])
        #expect(strip.strip.layout.counts[.working]?.isFolded == true)
    }

    /// Hidden, the strip catches up with what the card folded meanwhile.
    @Test func aStripHiddenTakesTheCardsFoldsAsItCatchesUp() throws {
        let folding = Folding(), notch = Self.opened(folding: folding), strip = Self.strip(folding: folding)

        _ = try Self.press("eyebrow:needsYou", in: notch)
        strip.catchUp(Self.at(strip.time + 500, isShown: false))

        #expect(strip.strip.layout.counts[.needsYou]?.isFolded == true)
    }

    /// Kept under the card's key, Snoozed alone folded at first, so either surface starts as Lee left both.
    @Test func theFoldsAreKeptForBoth() {
        let kept = SavedSettings<CardSettings>(MemoryDefaults())

        #expect(Folding(kept: kept).folds.sections == [.snoozed])

        Folding(kept: kept).set(.working, folded: true)
        #expect(kept.read().folded == [.working, .snoozed])
        #expect(Folding(kept: kept).folds.sections == [.working, .snoozed])
    }

    /// A click on a folded count unfolds it on the card and the strip at once, jumping nowhere: the run sets the fold
    /// where both read it, as a menu's Expand does.
    @Test func aClickOnAFoldedCountUnfoldsItForTheCardToo() {
        let folding = Folding()
        folding.set(.working, folded: true)
        let strip = Self.strip(folding: folding), count = CGPoint(x: 18, y: strip.strip.yOf(.count(.working)))

        strip.press(Self.at(strip.time, count))

        #expect(strip.release(EdgeSettings(), Self.at(strip.time, count)) == nil)
        #expect(folding.folds.sections == [.snoozed])
        #expect(strip.strip.folded == [.snoozed])
        #expect(strip.strip.layout.counts[.working] == nil)
    }

    // MARK: An arrival

    /// With the notch chosen, an arrival unfolds Needs you; with the strip chosen, Needs you stays folded, the strip's
    /// count flashing in its place.
    @Test(arguments: [true, false])
    func anArrivalUnfoldsNeedsYouOnlyWhileTheNotchIsChosen(isChosen: Bool) {
        let folding = Folding()
        folding.set(.needsYou, folded: true)
        let notch = NotchRun(at: 1000, in: Self.setting, folding: folding)
        var setting = Self.setting

        setting.isChosen = isChosen
        _ = notch.show(Self.board(Self.rows), NotchRun.Moment(time: notch.time, pointer: nil, setting: setting))
        _ = notch.show(
            Self.board([Self.ask("sr-c")] + Self.rows, new: ["ask:sr-c"]),
            NotchRun.Moment(time: notch.time, pointer: nil, setting: setting)
        )

        #expect(folding.folds.sections.contains(.needsYou) == !isChosen)
    }

    // MARK: Snoozed's marks

    /// A session with an ask in Needs you and asks asleep has a mark in each, the Snoozed one keyed apart, and a jump
    /// from either goes to the session.
    @Test func aSessionInNeedsYouAndInSnoozedHasAMarkInEach() throws {
        let folding = Folding()
        folding.set(.snoozed, folded: false)
        let board = Self.snoozedBoard(), strip = Self.strip(board, folding: folding)
        let asleep = try #require(board.snoozed.first)

        #expect(strip.strip.layout.places.map(\.id) == ["sr-qx81zt", "snoozed:sr-qx81zt"])
        guard case let .jump(session, to: target, click: _) = strip.jump(to: asleep, Self.at(strip.time)) else {
            Issue.record("the menu's jump found no mark")
            return
        }
        #expect(session.isSnoozed && target == "sr-qx81zt")
    }

    /// A turn Lee wakes moves into Needs you at once, unflashed, though the pointer rests on the strip; a menu open on
    /// its Snoozed mark as the board renames it still jumps, to its mark as the strip has it then, by the session's
    /// own id.
    @Test(arguments: [false, true])
    func aTurnLeeWakesMovesIntoNeedsYouAtOnceAndAMenuOpenOnItStillJumps(snoozedFolded: Bool) throws {
        let folding = Folding()
        folding.set(.snoozed, folded: snoozedFolded)
        let strip = Self.strip(Self.turnBoard(woken: false), folding: folding)
        let contoso = CGPoint(
            x: 18, y: strip.strip.yOf(snoozedFolded ? .count(.snoozed) : .session("snoozed:sr-c7m2qa"))
        )
        let asleep = try #require(Self.turnBoard(woken: false).snoozed.first { $0.id == "sr-c7m2qa" })
        let opened = try #require(strip.target(Self.at(strip.time, contoso)))

        #expect(opened == (snoozedFolded ? .count(.snoozed, isFolded: true) : .session(
            asleep, section: .snoozed, isFolded: false
        )))
        strip.menuOpened()
        strip.show(Self.turnBoard(woken: true), Self.at(strip.time))

        #expect(strip.strip.slot["sr-c7m2qa"] == .needsYou)
        #expect(strip.strip.layout.rest(of: .snoozed).allSatisfy { $0 != "snoozed:sr-c7m2qa" })
        #expect(Self.flash(in: strip, for: 1500) == 0)
        guard case let .jump(session, to: target, click: _) = strip.jump(to: asleep, Self.at(strip.time)) else {
            Issue.record("the menu's jump found no mark")
            return
        }
        #expect(!session.isSnoozed && target == "sr-c7m2qa")
    }

    /// Wake now, from a Snoozed mark's menu, on an ask of a session working: the board brings its row in Working into
    /// Needs you, nothing renamed, and its mark moves there at once, unflashed, though the menu holds the pointer on
    /// the strip.
    @Test func anAskWokenFromTheMenuIntoASessionWorkingMovesItsMarkIntoNeedsYouAtOnce() throws {
        let folding = Folding()
        folding.set(.snoozed, folded: false)
        let strip = Self.strip(Self.workingWithAskAsleep(woken: false), folding: folding)
        let asleep = CGPoint(x: 18, y: strip.strip.yOf(.session("snoozed:sr-qx81zt")))
        let working = try #require(strip.strip.mark(.session("sr-qx81zt")))

        #expect(strip.strip.slot["sr-qx81zt"] == .working)
        guard case .session(_, section: .snoozed, isFolded: false)? = strip.target(Self.at(strip.time, asleep)) else {
            Issue.record("the right-click found no Snoozed mark")
            return
        }
        strip.menuOpened()
        strip.show(Self.workingWithAskAsleep(woken: true), Self.at(strip.time))

        #expect(strip.strip.mark(.session("sr-qx81zt")) === working)
        #expect(strip.strip.slot["sr-qx81zt"] == .needsYou)
        #expect(try #require(strip.strip.layout.y(of: "sr-qx81zt")) < #require(strip.strip.layout.hairs[.working]))
        #expect(Self.flash(in: strip, for: 1500) == 0)
        #expect(strip.strip.over)
    }

    /// A Snoozed mark's tab says when it wakes, as its row on the card does; any other its age.
    @Test func aSnoozedTabSaysWhenItWakes() throws {
        let board = Self.snoozedBoard(), asleep = try #require(board.snoozed.first)
        let now = 1_792_741_527_619.0

        #expect(StripNote(board).age(asleep, at: now, in: Self.london) == asleep.timeText(at: now, in: Self.london))
        #expect(StripNote(board).age(asleep, at: now, in: Self.london) != asleep.ageText(at: now))
        #expect(StripNote(board).age(board.sessions[0], at: now, in: Self.london) == board.sessions[0].ageText(at: now))
    }

    // MARK: The right-click

    @Test func aRightClickNamesWhatIsUnderIt() throws {
        let folding = Folding()
        folding.set(.working, folded: true)
        let strip = Self.strip(folding: folding)
        let ask = CGPoint(x: 18, y: strip.strip.yOf(.session("sr-a")))
        let count = CGPoint(x: 18, y: strip.strip.yOf(.count(.working)))

        #expect(strip.target(Self.at(strip.time, ask)) == .session(
            try #require(strip.board.sessions.first), section: .needsYou, isFolded: false
        ))
        #expect(strip.target(Self.at(strip.time, count)) == .count(.working, isFolded: true))
        #expect(strip.target(Self.at(strip.time, CGPoint(x: 600, y: 400))) == nil)
    }

    /// While a menu shows, the strip holds as if the pointer rested where it was opened, the tab out staying out
    /// however long; closed, the pointer is where it is again, and the tab draws back.
    @Test func aMenuHoldsTheStripAsThePointerLeftIt() {
        let strip = Self.strip(folding: Folding())
        let ask = CGPoint(x: 18, y: strip.strip.yOf(.session("sr-a")))

        Self.frames(strip, for: 2000, ask) { strip.strip.liveTab()?.phase == .open }
        _ = strip.target(Self.at(strip.time, ask))
        strip.menuOpened()
        Self.frames(strip, for: 3000, nil)
        #expect(strip.strip.liveTab()?.phase == .open)

        strip.menuClosed()
        Self.frames(strip, for: 3000, nil)
        #expect(strip.strip.liveTab() == nil)
    }

    /// While a menu shows, the hover holds on what it was asked at: a board sliding another mark under the point pours
    /// nothing, the tab out staying with its own mark.
    @Test func aMenuHoldsTheHoverThoughABoardSlidesAnotherMarkUnderThePoint() throws {
        let strip = Self.strip(folding: Folding())
        let b = CGPoint(x: 18, y: strip.strip.yOf(.session("sr-b")))
        Self.frames(strip, for: 2000, b) { strip.strip.liveTab()?.phase == .open }
        _ = try #require(strip.target(Self.at(strip.time, b)))
        strip.menuOpened()

        let asks = ["sr-a", "sr-c", "sr-d", "sr-b"].map(Self.ask)
        strip.show(Self.board(asks + [Self.working("sr-w")]), Self.at(strip.time))
        Self.frames(strip, for: 2000, nil)

        #expect(abs(strip.strip.yOf(.session("sr-d")) - b.y) < 0.01)
        #expect(strip.strip.liveTab()?.key == .session("sr-b"))
        #expect(!strip.strip.tabs.contains { $0.key == .session("sr-d") })
    }

    /// A row new to the board while a menu is open comes in at its place, and nothing else re-sorts under the menu: the
    /// asks' order, changed a moment before, waits for the menu to close and the pointer to have been off the strip
    /// for Settle (Lee, 14 November 2026; until then a new row re-sorted them all).
    @Test func aNewRowWhileAMenuIsOpenReSortsNothing() throws {
        let strip = Self.strip(folding: Folding())
        let mark = CGPoint(x: 18, y: strip.strip.yOf(.session("sr-w")))
        _ = try #require(strip.target(Self.at(strip.time, mark)))
        strip.menuOpened()
        let again = WatchLine.Row(
            session: "sr-a", name: "sr-a", projectName: "Contoso",
            lines: [.init("ask:sr-a", .ask, first: "Ask sr-a again", since: Self.since + 1000)]
        )
        let asks = [Self.ask("sr-b"), again, Self.working("sr-w")]
        strip.show(Self.board(asks), Self.at(strip.time))

        strip.show(Self.board(asks + [Self.working("sr-n")]), Self.at(strip.time))

        #expect(strip.strip.display == ["sr-a", "sr-b", "sr-w", "sr-n"])
        strip.menuClosed()
        Self.frames(strip, for: 2000, nil)
        #expect(strip.strip.display == ["sr-b", "sr-a", "sr-w", "sr-n"])
    }

    /// A menu's Jump to the window jumps as a click on the mark does, by the session's own id, its mark pressing in;
    /// with another jump spinning, or the session gone from the strip, it jumps all the same, pressing nothing.
    @Test func aMenusJumpJumpsAsAClickOnTheMark() throws {
        let strip = Self.strip(folding: Folding())
        let working = try #require(strip.board.sessions.first { $0.id == "sr-w" })
        let ask = try #require(strip.board.sessions.first { $0.id == "sr-a" })
        let gone = Session(id: "sr-gone", project: "P", kind: .working, title: "Gone", sub: "P", since: 0)

        #expect(strip.jump(to: working, Self.at(strip.time)) == .jump(working, to: "sr-w", click: 1))
        #expect(Self.pressed(in: strip) == .session("sr-w"))
        #expect(strip.jump(to: ask, Self.at(strip.time)) == .jump(ask, to: "sr-a", click: 2))
        #expect(strip.jump(to: gone, Self.at(strip.time)) == .jump(gone, to: "sr-gone", click: 3))
        #expect(Self.pressed(in: strip) == .session("sr-w"))
    }

    // MARK: Helpers

    private static let frameMS = 1000.0 / 60
    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false, isChosen: true
    )
    private static let stripSetting = StripRun.Setting(
        stage: StripStage(width: 1512, height: 982, menu: 37), reducesMotion: false
    )
    private static let onTheNotch = CGPoint(x: 3, y: 491)
    private static let rows = [ask("sr-a"), ask("sr-b"), working("sr-w")]

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private static func at(_ notch: NotchRun, _ time: Double, _ pointer: CGPoint? = nil) -> NotchRun.Moment {
        NotchRun.Moment(time: time, pointer: pointer, setting: setting)
    }

    private static func at(_ time: Double, _ pointer: CGPoint? = nil, isShown: Bool = true) -> StripRun.Moment {
        StripRun.Moment(time: time, pointer: pointer, isShown: isShown, setting: stripSetting)
    }

    private static let since = 1_792_445_000_000

    private static func ask(_ id: String) -> WatchLine.Row {
        WatchLine.Row(
            session: id, name: id, projectName: "Contoso",
            lines: [.init("ask:\(id)", .ask, first: "Ask \(id)", since: since)]
        )
    }

    private static func working(_ id: String) -> WatchLine.Row {
        WatchLine.Row(
            session: id, name: id, lines: [.init("work:\(id)", .working, first: "Running the tests", since: since)]
        )
    }

    private static func board(
        _ rows: [WatchLine.Row], new: [String] = [], snoozed: [WatchLine.SnoozedRow] = []
    ) -> PanelBoard {
        var last = LastBoard()
        let line = WatchLine(head: .init(needYou: 0, sessions: rows.count), rows: rows, snoozed: snoozed, new: new)

        _ = last.hear(.line(line.text), at: Date())
        return PanelBoard(last)
    }

    /// Fabrikam's session, an ask waiting in Needs you and another asleep in Snoozed.
    private static func snoozedBoard() -> PanelBoard {
        board(
            [Self.fabrikam(.init("ask:sr-qx81zt:k3", .ask, first: "Give the go", since: since))],
            snoozed: [Self.asleep("k1", lead: "Review the plan")]
        )
    }

    /// Fabrikam's session working, an ask of it asleep in Snoozed, beside the asks and Northwind's session working;
    /// then, `woken` by Lee, the ask back in Needs you by its key there, so new on no line.
    private static func workingWithAskAsleep(woken: Bool) -> PanelBoard {
        let key = "ask:sr-qx81zt:k1", lead = "Which region goes first?"

        guard woken else {
            let work = Self.fabrikam(.init("work:sr-qx81zt", .working, first: "Drafting", since: since))

            return board(rows + [work], snoozed: [Self.asleep("k1", lead: lead)])
        }
        return board([Self.fabrikam(.init(key, .ask, first: .init(lead: lead), since: since))] + rows)
    }

    /// Fabrikam's session, its row of this line.
    private static func fabrikam(_ line: WatchLine.Row.Line) -> WatchLine.Row {
        WatchLine.Row(session: "sr-qx81zt", name: "Region rollout", projectName: "Fabrikam", lines: [line])
    }

    /// Fabrikam's ask asleep in Snoozed, by its id, waking in an hour.
    private static func asleep(_ ask: String, lead: String) -> WatchLine.SnoozedRow {
        WatchLine.SnoozedRow(
            session: "sr-qx81zt", name: "Region rollout", projectName: "Fabrikam",
            lines: [
                .init(
                    "ask:sr-qx81zt:\(ask)", ask: ask, first: .init(lead: lead), since: since, wakesAt: since + 3_600_000
                ),
            ]
        )
    }

    /// Northwind's session at its turn, and Contoso's turn Lee snoozed until it moves; then, `woken` by Lee, Contoso's
    /// back at its turn in Needs you, by its turn's key there.
    private static func turnBoard(woken: Bool) -> PanelBoard {
        let key = "turn:sr-c7m2qa", lead: WatchLine.Words = "The flow is drawn"
        let northwind = WatchLine.Row(
            session: "sr-n4w8rt",
            lines: [.init("turn:sr-n4w8rt", .yourTurn, first: "The export is done", since: since + 60000)]
        )

        guard woken else {
            let asleep = WatchLine.SnoozedRow(
                session: "sr-c7m2qa", name: "Onboarding flow", projectName: "Contoso",
                lines: [.init(key, .yourTurn, first: lead, since: since, wakesAt: nil)]
            )

            return board([northwind], snoozed: [asleep])
        }
        let contoso = WatchLine.Row(
            session: "sr-c7m2qa", name: "Onboarding flow", projectName: "Contoso",
            lines: [.init(key, .yourTurn, first: lead, since: since)]
        )

        return board([northwind, contoso])
    }

    /// The mark a jump spinning pressed in, if one did.
    private static func pressed(in strip: StripRun) -> MarkKey? {
        guard case let .mark(key)? = strip.strip.jumping else {
            return nil
        }

        return key
    }

    /// The brightest any mark's ring flashed, or its inside washed, over this long, the pointer away unless a menu
    /// holds it.
    private static func flash(in strip: StripRun, for ms: Double) -> Double {
        var flash = 0.0

        frames(strip, for: ms, nil) {
            flash = max(flash, strip.frame.marks.map { max($0.flash, $0.wash) }.max() ?? 0)
            return false
        }
        return flash
    }

    /// A notch over the board, folded as `folding` has it, its panel opened by the pointer held on it.
    private static func opened(folding: Folding) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting, folding: folding)

        _ = run.show(board(rows), at(run, run.time))
        while run.phase != .open, run.time < 6000 {
            run.step(at(run, run.time + frameMS, onTheNotch))
        }
        return run
    }

    /// A strip over the board, folded as `folding` has it, come to rest.
    private static func strip(_ board: PanelBoard = board(rows), folding: Folding) -> StripRun {
        let run = StripRun(at: 1000, in: stripSetting, EdgeSettings(), folding: folding, measure: measure)

        run.show(board, at(run.time))
        frames(run, for: 3000, nil) { !run.frame.isMoving }
        return run
    }

    private static func measure(_ note: @escaping () -> StripNote) -> StripMeasure {
        StripMeasure.uniform(230)
    }

    private static func frames(
        _ run: StripRun, for ms: Double, _ pointer: CGPoint?, until done: () -> Bool = { false }
    ) {
        let end = run.time + ms

        while run.time + frameMS <= end + 1e-9 {
            run.step(at(run.time + frameMS, pointer))
            if done() {
                return
            }
        }
    }

    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.map(\.item.key)
    }

    private static func press(_ key: String, in run: NotchRun) throws -> NotchRun.Press? {
        let panel = try #require(run.frame.panel)
        let index = try #require(run.list.content.entries.firstIndex { $0.item.key == key })
        let item = run.list.content.itemFrame(index), drawn = run.list.content.entries[index].item.box(width: item.width)
        let point = CGPoint(x: panel.frame.minX + item.midX, y: panel.frame.minY + item.minY + drawn.midY - run.scroll)

        return run.press(at(run, run.time, point))
    }
}
