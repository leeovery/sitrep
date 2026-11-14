import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepLines
@testable import SitRepPanel
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

    /// A click on a folded count unfolds it on the card too, jumping nowhere.
    @Test func aClickOnAFoldedCountUnfoldsItForTheCardToo() {
        let folding = Folding()
        folding.set(.working, folded: true)
        let strip = Self.strip(folding: folding), count = CGPoint(x: 18, y: strip.strip.yOf(.count(.working)))

        strip.press(Self.at(strip.time, count))

        #expect(strip.release(EdgeSettings(), Self.at(strip.time, count)) == nil)
        #expect(folding.folds.sections == [.snoozed])
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
        let strip = Self.strip(Self.snoozedBoard(), folding: folding)

        #expect(strip.strip.layout.places.map(\.id) == ["sr-4g01a7", "snoozed:sr-4g01a7"])
        guard case let .jump(session, to: target, click: _)? = strip.jump(to: "snoozed:sr-4g01a7", Self.at(strip.time))
        else {
            Issue.record("the menu's jump found no mark")
            return
        }
        #expect(session.isSnoozed && target == "sr-4g01a7")
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

        #expect(strip.target(Self.at(strip.time, ask)) == .session(try #require(strip.board.sessions.first)))
        #expect(strip.target(Self.at(strip.time, count)) == .count(.working, isFolded: true))
        #expect(strip.target(Self.at(strip.time, CGPoint(x: 600, y: 400))) == nil)
    }

    /// While a menu shows, the strip holds as if the pointer rested where it was opened, the tab out staying out
    /// however long; closed, the pointer is where it is again, and the tab draws back.
    @Test func aMenuHoldsTheStripAsThePointerLeftIt() {
        let strip = Self.strip(folding: Folding())
        let ask = CGPoint(x: 18, y: strip.strip.yOf(.session("sr-a")))

        Self.frames(strip, for: 2000, ask) { strip.strip.liveTab()?.phase == .open }
        strip.menuOpened(at: ask)
        Self.frames(strip, for: 3000, nil)
        #expect(strip.strip.liveTab()?.phase == .open)

        strip.menuClosed()
        Self.frames(strip, for: 3000, nil)
        #expect(strip.strip.liveTab() == nil)
    }

    /// A menu's Jump to the window jumps as a click on the mark does, by the session's own id.
    @Test func aMenusJumpJumpsAsAClickOnTheMark() {
        let strip = Self.strip(folding: Folding())

        guard case let .jump(session, to: target, click: click)? = strip.jump(to: "sr-w", Self.at(strip.time)) else {
            Issue.record("the menu's jump found no mark")
            return
        }
        #expect(session.id == "sr-w" && target == "sr-w" && click == 1)
        #expect(strip.jump(to: "sr-gone", Self.at(strip.time)) == nil)
    }

    // MARK: Helpers

    private static let frameMS = 1000.0 / 60
    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false
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

    private static func ask(_ id: String) -> String {
        row("ask:\(id)", "ask", session: id, lead: "Ask \(id)", second: "SitRep · \(id)", since: 1_792_445_000_000)
    }

    private static func working(_ id: String) -> String {
        row("work:\(id)", "working", session: id, lead: "Running the tests", second: "DocMan · \(id)", since: 1_792_445_000_000)
    }

    private static func board(_ rows: [String], new: [String] = []) -> PanelBoard {
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: 0, sessions: rows.count, new: new, rows: rows)), at: Date())
        return PanelBoard(last)
    }

    /// The real CLI's first line with asks asleep (`Lines.snoozed`): a session with an ask in Needs you and two in
    /// Snoozed.
    private static func snoozedBoard() -> PanelBoard {
        var last = LastBoard()

        _ = last.hear(.line(Lines.snoozed[0]), at: .now)
        return PanelBoard(last)
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
        StripMeasure(row: { _ in 230 }, rows: { _ in 230 }, idle: { 230 })
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
